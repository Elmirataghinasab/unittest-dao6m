const https = require("https");
const FormData = require("form-data");
const fs = require("fs");
const readlineSync = require("readline-sync");

const pinataApiKey = "5f72c9cf5a1ad2729bc9";
const pinataSecretApiKey =
  "334beac3031ce9bcaa83e39f22df0b0049d731dd20bc79638f68a0cc10bb2e85";

// Base path for files
const basePath = "./ipfs-files/files/";

async function uploadToPinata(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error("File does not exist:", filePath);
    return;
  }

  const data = new FormData();
  data.append("file", fs.createReadStream(filePath));

  const metadata = JSON.stringify({
    name: "MyFile",
    keyvalues: {
      description: "Sample file upload to Pinata",
    },
  });
  data.append("pinataMetadata", metadata);

  const options = JSON.stringify({
    cidVersion: 1,
  });
  data.append("pinataOptions", options);

  const requestOptions = {
    method: "POST",
    hostname: "api.pinata.cloud",
    path: "/pinning/pinFileToIPFS",
    headers: {
      ...data.getHeaders(),
      pinata_api_key: pinataApiKey,
      pinata_secret_api_key: pinataSecretApiKey,
    },
  };

  const req = https.request(requestOptions, (res) => {
    let responseData = "";

    res.on("data", (chunk) => {
      responseData += chunk;
    });

    res.on("end", () => {
      if (res.statusCode === 200) {
        console.log("File uploaded to IPFS:", JSON.parse(responseData));
      } else {
        console.error("Error uploading file:", responseData);
      }
    });
  });

  req.on("error", (error) => {
    console.error("Request error:", error);
  });

  data.pipe(req);
}

// Get the file name from the user
const fileName = readlineSync.question(
  "Enter the file name (with extension): "
);
const fullPath = `${basePath}${fileName}`;

// Upload the file to Pinata
uploadToPinata(fullPath);
