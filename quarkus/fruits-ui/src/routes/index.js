var express = require("express");
var router = express.Router();
require("dotenv").config();
const axios = require("axios");
const background = process.env.BACKGROUND_COLOR;

const api = axios.create({
  baseURL: process.env.API_BASE_URL,
  params: {},
  timeout: process.env.TIMEOUT || 15000,
});

/* GET home page. */
router.get("/", async function (req, res, next) {
  try {
    console.log("Sending request to backend fruits api");
    var data = await api.get("/fruits");
    console.log("Response from backend fruits api: ", data.data);
    res.render("index", {
      fruits: data.data,
      background_color: background,
    });
  } catch (err) {
    console.log("Error: ", err);
    next(err);
  }
});

module.exports = router;
