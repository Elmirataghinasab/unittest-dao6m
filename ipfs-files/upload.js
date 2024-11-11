const https = require("https");
const FormData = require("form-data");
const fs = require("fs");

const pinataApiKey = "5f72c9cf5a1ad2729bc9";
const pinataSecretApiKey =
  "334beac3031ce9bcaa83e39f22df0b0049d731dd20bc79638f68a0cc10bb2e85";

async function uploadToPinata(filePath) {
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

// Example usage
uploadToPinata("./ipfs-files/files/karlancer.jpg");