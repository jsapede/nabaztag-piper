#!/usr/bin/env python3
"""
Python TTS Server for Nabaztag - Replaces Docker-based Piper service
Handles French accent processing and streams audio to Nabaztag
"""

import argparse
import logging
import subprocess
import sys
import unicodedata
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[TTS-Server] %(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# French accent mapping for proper pronunciation
ACCENT_MAPPING = {
    'à': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'ù': 'u', 'û': 'u', 'ü': 'u',
    'ï': 'i', 'î': 'i',
    'ç': 'c',
    'ô': 'o', 'ö': 'o',
    'â': 'a', 'ê': 'e',
}

# Normalize French text for better TTS pronunciation
def normalize_french_text(text):
    """Normalize French text for better TTS pronunciation"""
    # Convert to lowercase for consistency
    text = text.lower()
    
    # Replace accented characters with their base form
    # This helps Piper handle French text better
    normalized = []
    for char in text:
        if char in ACCENT_MAPPING:
            normalized.append(ACCENT_MAPPING[char])
        else:
            normalized.append(char)
    
    return ''.join(normalized)

# Format text for TTS (add phonetic hints for difficult words)
def format_text_for_tts(text):
    """Format text for optimal TTS pronunciation"""
    # Normalize accents
    text = normalize_french_text(text)
    
    # Add phonetic hints for common French words
    # This is a simple approach - could be enhanced with a dictionary
    replacements = {
        'rue': 'rue',  # Keep as is, Piper should handle it
        'rue ': 'rue ',  # With space
    }
    
    for old, new in replacements.items():
        text = text.replace(old, new)
    
    return text

class TTSHandler(BaseHTTPRequestHandler):
    """HTTP handler for TTS requests"""
    
    protocol_version = "HTTP/1.0"  # Use HTTP/1.0 for compatibility
    
    def do_GET(self):
        """Handle GET requests for TTS"""
        if not self.path.startswith("/tts"):
            self.send_error(404, "Not Found")
            return
        
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        
        text = params.get('t', [''])[0]
        voice = params.get('voice', ['fr_FR-tom-medium'])[0]
        
        if not text:
            self.send_error(400, "Missing 't' parameter")
            return
        
        logger.info(f"Processing TTS request: '{text}' with voice: {voice}")
        
        try:
            # Format text for TTS
            formatted_text = format_text_for_tts(text)
            logger.info(f"Formatted text: '{formatted_text}'")
            
            # Build Piper command
            piper_cmd = [
                'piper',
                '--model', '/opt/configs/nabserver/voices/fr_FR-tom-medium.onnx',
                '--length_scale', '1.5',
                '--output_raw',
            ]
            
            # Start Piper process
            logger.info("Starting Piper TTS...")
            piper_proc = subprocess.Popen(
                piper_cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                bufsize=0
            )
            
            # Send text to Piper
            piper_proc.stdin.write(formatted_text.encode('utf-8'))
            piper_proc.stdin.close()
            
            # Send response headers to Nabaztag
            self.send_response(200)
            self.send_header("Content-Type", "audio/wav")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            
            # Stream audio from Piper to Nabaztag
            bytes_sent = 0
            try:
                while True:
                    chunk = piper_proc.stdout.read(8192)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    bytes_sent += len(chunk)
            except (BrokenPipeError, ConnectionResetError):
                logger.info("Client disconnected during streaming")
            finally:
                piper_proc.kill()
                piper_proc.wait()
            
            logger.info(f"Streamed {bytes_sent} bytes to Nabaztag")
            
        except FileNotFoundError:
            logger.error("Piper executable not found. Make sure Piper is installed and in PATH.")
            self.send_response(500)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Piper TTS not available")
        except Exception as e:
            logger.error(f"TTS processing error: {e}", exc_info=True)
            self.send_response(500)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(f"Error: {e}".encode())
    
    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info(format % args)


def main():
    parser = argparse.ArgumentParser(
        description="Python TTS Server for Nabaztag - Handles French accents"
    )
    parser.add_argument(
        '--host',
        default='0.0.0.0',
        help='Host to bind (default: 0.0.0.0)'
    )
    parser.add_argument(
        '--port',
        type=int,
        default=6790,
        help='Port to listen on (default: 6790)'
    )
    parser.add_argument(
        '--log-level',
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        default='INFO',
        help='Logging level (default: INFO)'
    )
    
    args = parser.parse_args()
    
    # Set logging level
    logger.setLevel(args.log_level)
    
    logger.info(f"Starting Python TTS Server on {args.host}:{args.port}")
    logger.info("French accent processing enabled")
    logger.info("Serving: http://%s:%d/tts?t=<text>&voice=<voice>" % (args.host, args.port))
    
    server = HTTPServer((args.host, args.port), TTSHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopped")
        sys.exit(0)


if __name__ == '__main__':
    main()