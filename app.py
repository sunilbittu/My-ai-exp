import os
import openai
import base64
from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
from dotenv import load_dotenv

load_dotenv() # Load environment variables from .env file, if present

app = Flask(__name__)

# --- IMPORTANT: OpenAI API Key Configuration ---
# Option 1: Set OPENAI_API_KEY as an environment variable.
# Option 2: Directly replace "YOUR_OPENAI_API_KEY_HERE" with your actual key.
# For security, using an environment variable is highly recommended.
openai.api_key = os.getenv("OPENAI_API_KEY", "YOUR_OPENAI_API_KEY_HERE")

# --- Configuration ---
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def encode_image_to_base64(image_path):
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

@app.route('/summarize-image', methods=['POST'])
def summarize_image():
    if openai.api_key == "YOUR_OPENAI_API_KEY_HERE":
        return jsonify({"error": "OpenAI API key not configured. Please set it in app.py or as an environment variable."}), 500

    if 'image' not in request.files:
        return jsonify({"error": "No image file provided"}), 400

    file = request.files['image']

    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        image_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(image_path)

        try:
            base64_image = encode_image_to_base64(image_path)

            response = openai.ChatCompletion.create(
                model="gpt-4-vision-preview", # Or the latest available vision model
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "Summarize this image."},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{base64_image}"
                                }
                            }
                        ]
                    }
                ],
                max_tokens=300
            )

            summary = response.choices[0].message.content
            os.remove(image_path) # Clean up the uploaded image
            return jsonify({"summary": summary})

        except openai.error.OpenAIError as e:
            # Handle OpenAI API errors (e.g., authentication, rate limits)
            if os.path.exists(image_path):
                 os.remove(image_path)
            return jsonify({"error": f"OpenAI API error: {str(e)}"}), 500
        except Exception as e:
            # Handle other potential errors during processing
            if os.path.exists(image_path):
                 os.remove(image_path)
            return jsonify({"error": f"Error processing image: {str(e)}"}), 500
    else:
        return jsonify({"error": "File type not allowed"}), 400

if __name__ == '__main__':
    # It's recommended to use a production-ready WSGI server like Gunicorn or Waitress
    # For development, Flask's built-in server is fine.
    # Ensure to listen on 0.0.0.0 to make it accessible from the React app (if running in a different container/machine)
    app.run(host='0.0.0.0', port=5000, debug=True)

