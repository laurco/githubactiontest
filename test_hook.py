import os
import hmac
import hashlib
from http.server import BaseHTTPRequestHandler, HTTPServer

# Récupère le secret depuis la variable d'environnement
WEBHOOK_SECRET = os.environ.get("GITHUB_WEBHOOK_SECRET")
if not WEBHOOK_SECRET:
    raise RuntimeError("La variable d'environnement GITHUB_WEBHOOK_SECRET n'est pas définie")
WEBHOOK_SECRET = WEBHOOK_SECRET.encode()

PORT = 8000

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers['Content-Length'])
        body = self.rfile.read(length)

        # Vérification de la signature
        signature = self.headers.get('X-Hub-Signature-256', '')
        digest = 'sha256=' + hmac.new(WEBHOOK_SECRET, body, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(signature, digest):
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b"Unauthorized")
            return

        # Router selon l'événement GitHub
        event = self.headers.get('X-Github-Event')
        if event == 'push':
            print("Push event reçu :", body.decode())
        elif event == 'pull_request':
            print("Pull request event :", body.decode())
        else:
            print(f"Événement {event} reçu :", body.decode())

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")

        
httpd = HTTPServer(('0.0.0.0', PORT), WebhookHandler)
print(f"Listening on port {PORT}")
httpd.serve_forever()
