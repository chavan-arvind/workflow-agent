const functions = require('@google-cloud/functions-framework');
const { Storage } = require('@google-cloud/storage');
const { execSync } = require('child_process');
const tmp = require('tmp');
const fs = require('fs');
const path = require('path');
const { GoogleGenerativeAI } = require('@google/generative-ai');

console.log('Starting application...');

// Main handler function
exports.handler = functions.http('handler', (req, res) => {
  console.log('Received request:', req.path);
  const reqPath = req.path;
  
  if (reqPath === '/cloneRepoToStorage') {
    return cloneRepoToStorage(req, res);
  } else if (reqPath === '/analyzeCode') {
    return analyzeCode(req, res);
  } else {
    res.status(404).send('Not Found');
  }
});

// New function to analyze code using Gemini
functions.http('analyzeCode', async (req, res) => {
  try {
    const { bucketName, repoPath } = req.body;

    if (!bucketName || !repoPath) {
      return res.status(400).json({ error: 'Missing bucketName or repoPath parameter.' });
    }

    const storage = new Storage();
    const bucket = storage.bucket(bucketName);

    const code = await fetchCodeFromBucket(bucket, repoPath);
    const analysis = await analyzeCodeWithGemini(code);
    await writeAnalysisToBucket(bucket, repoPath, analysis);

    res.status(200).json({ message: 'Code analyzed and result saved successfully.' });
  } catch (error) {
    console.error('Error analyzing code:', error);
    res.status(500).json({ error: 'Error analyzing code.' });
  }
});

function isValidUrl(url) {
  try {
    new URL(url);
    return url.startsWith('https://');
  } catch {
    return false;
  }
}

async function cloneRepository(repoUrl, repoPath) {
  await execSync(`git clone ${repoUrl} ${repoPath}`, { stdio: 'inherit' });
}

async function uploadRepository(repoPath, bucket) {
  const files = walkSync(repoPath);
  const uploadPromises = files.map(file => {
    const destination = path.relative(repoPath, file);
    return bucket.upload(file, { destination });
  });
  await Promise.all(uploadPromises);
}

async function fetchCodeFromBucket(bucket, repoPath) {
  const [files] = await bucket.getFiles({ prefix: repoPath });
  let code = '';
  for (const file of files) {
    if (file.name.endsWith('.js') || file.name.endsWith('.py') || file.name.endsWith('.java')) {
      const [contents] = await file.download();
      code += `\n// File: ${file.name}\n${contents.toString('utf-8')}\n`;
    }
  }
  return code;
}

async function analyzeCodeWithGemini(code) {
  const apiKey = process.env.GEMINI_API_KEY;
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: 'gemini-pro' });

  const prompt = `Analyze the following code and provide insights on code quality, potential improvements, and any security concerns:

${code}

Please provide your analysis in a structured format with sections for:
1. Code Quality
2. Potential Improvements
3. Security Concerns
4. Overall Assessment`;

  const result = await model.generateContent(prompt);
  const response = await result.response;
  return response.text();
}

async function writeAnalysisToBucket(bucket, repoPath, analysis) {
  const analysisFileName = `${repoPath}/code_analysis.txt`;
  const file = bucket.file(analysisFileName);
  await file.save(analysis);
}

function walkSync(dir, filelist = []) {
  fs.readdirSync(dir).forEach(file => {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      filelist = walkSync(filePath, filelist);
    } else {
      filelist.push(filePath);
    }
  });
  return filelist;
}

// Export the functions
exports.cloneRepoToStorage = functions.http('cloneRepoToStorage', async (req, res) => {
  // Implement your cloneRepoToStorage logic here
  // This is a placeholder implementation
  res.status(200).send('cloneRepoToStorage function called');
});

exports.analyzeCode = functions.http('analyzeCode', async (req, res) => {
  try {
    const { bucketName, repoPath } = req.body;

    if (!bucketName || !repoPath) {
      return res.status(400).json({ error: 'Missing bucketName or repoPath parameter.' });
    }

    const storage = new Storage();
    const bucket = storage.bucket(bucketName);

    const code = await fetchCodeFromBucket(bucket, repoPath);
    const analysis = await analyzeCodeWithGemini(code);
    await writeAnalysisToBucket(bucket, repoPath, analysis);

    res.status(200).json({ message: 'Code analyzed and result saved successfully.' });
  } catch (error) {
    console.error('Error analyzing code:', error);
    res.status(500).json({ error: 'Error analyzing code.' });
  }
});

// Start the server
const port = process.env.PORT || 8080;
console.log(`Attempting to start server on port ${port}`);
functions.http.start(port).then(() => {
  console.log(`Server successfully started and listening on port ${port}`);
}).catch((error) => {
  console.error('Failed to start server:', error);
});

console.log(`Server listening on port ${port}`);