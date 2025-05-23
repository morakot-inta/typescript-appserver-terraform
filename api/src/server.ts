import express from "express";

const app = express();
const PORT = process.env.PORT || 8080;

app.get("/", (req, res) => {
  res.json({ message: "Welcome to the API1!" });
});

// Add health check endpoint
app.get("/health", (req, res) => {
  res.status(200).send("Healthy");
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
