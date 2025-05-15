import React, { useState } from 'react';
import './App.css';

function App() {
  const [selectedFile, setSelectedFile] = useState(null);
  const [summary, setSummary] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleFileChange = (event) => {
    setSelectedFile(event.target.files[0]);
    setSummary('');
    setError('');
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    if (!selectedFile) {
      setError('Please select an image file first.');
      return;
    }

    const formData = new FormData();
    formData.append('image', selectedFile);

    setIsLoading(true);
    setError('');
    setSummary('');

    try {
      // Assuming the backend is running on http://localhost:5000
      // If your backend is on a different port or host, update this URL.
      const response = await fetch('http://localhost:5000/summarize-image', {
        method: 'POST',
        body: formData,
      });

      const data = await response.json();

      if (response.ok) {
        setSummary(data.summary);
      } else {
        setError(data.error || 'An unknown error occurred.');
      }
    } catch (err) {
      console.error('Error uploading image:', err);
      setError('Failed to connect to the server. Please ensure the backend is running and accessible.');
    }
    setIsLoading(false);
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Image Summarizer</h1>
        <p>Upload an image to get a summary using OpenAI GPT-4 Vision.</p>
      </header>
      <main>
        <form onSubmit={handleSubmit} className="upload-form">
          <div className="file-input-container">
            <input type="file" id="file" onChange={handleFileChange} accept="image/*" />
            <label htmlFor="file" className="file-input-label">
              {selectedFile ? selectedFile.name : 'Choose an image'}
            </label>
          </div>
          <button type="submit" disabled={isLoading || !selectedFile}>
            {isLoading ? 'Summarizing...' : 'Get Summary'}
          </button>
        </form>

        {error && <p className="error-message">Error: {error}</p>}
        
        {summary && (
          <div className="summary-container">
            <h2>Summary:</h2>
            <p>{summary}</p>
          </div>
        )}
      </main>
      <footer>
        <p>Powered by Manus AI</p>
      </footer>
    </div>
  );
}

export default App;

