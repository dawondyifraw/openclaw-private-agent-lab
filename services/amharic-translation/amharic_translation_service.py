
from flask import Flask, request, jsonify
from amharic_translation import AmharicTranslationPipeline
import os

app = Flask(__name__)
pipeline = AmharicTranslationPipeline()

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok", "model": pipeline.model_name})

@app.route('/translate/amharic', methods=['POST'])
def translate_amharic():
    data = request.json
    text = data.get('text', '')
    if not text:
        return jsonify({"error": "No text provided"}), 400
    
    result = pipeline.translate(text)
    return jsonify(result)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 18790))
    app.run(host='0.0.0.0', port=port)
