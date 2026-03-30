'use strict';

/* eslint-disable global-require */

const path = require('path');
const express = require('express');
const session = require('express-session');

const cliOptions = [
  { name: 'environment', alias: 'e', type: String },
  { name: 'port', alias: 'p', type: Number },
  { name: 'help', alias: 'h', type: Boolean }
];
const options = require('command-line-args')(cliOptions);
const environment = options.environment || 'development';
const port = options.port || 9000;

// server init
const app = express();
const server = require('http').createServer(app);

app.use(session({
  secret: 'SeeTheSea',
  resave: false,
  saveUninitialized: true
}));

const targetCourse = 0;
const deviation = 45;
let course = targetCourse;
let rsa = 0;

setInterval(() => {
  let newCourse = (Math.random() - 0.5) * 2 * deviation + targetCourse;
  if (Math.abs(course - newCourse) > 180) {
    if (newCourse > course) {
      newCourse -= 360;
    } else {
      newCourse += 360;
    }
  }
  course = (course * 49 + newCourse) / 50;
  if (course < 0) {
    course += 360;
  } else if (course >= 360) {
    course -= 360;
  }
  rsa = (rsa * 49 + (Math.random() - 0.5) * 2 * 10) / 50;
}, 250);

app.get('/api/helm', (req, res) => {
  res.set('Cache-Control', 'no-cache');
  res.send({
    cgfa: course,
    coga: course,
    hdga: course,
    cgf: course,
    cog: course,
    hdg: course,
    wa: course,
    rsa,
  });
});

app.use('/api', (req, res) => {
  res.status(404).end();
});

if (environment === 'development') {
  const webpack = require('webpack');
  const webpackDevMiddleware = require('webpack-dev-middleware');
  const webpackCfg = require('./webpack.config.js');
  const { publicPath } = webpackCfg.output;
  const compiler = webpack(webpackCfg);
  const devMiddleware = webpackDevMiddleware(compiler, { publicPath });

  app.use(devMiddleware);
  app.use((req, res) => {
    res.type('html');
    res.end(devMiddleware.fileSystem.readFileSync(path.join(webpackCfg.output.path, 'index.htm')));
  });
} else {
  const distPath = path.resolve(`${__dirname}/data`);
  app.use('/', express.static(distPath));
  app.use((req, res) => {
    res.sendFile(`${distPath}/index.htm`);
  });
}

server.listen(port, () => {
  console.log(`${new Date().toUTCString()}: process ${process.pid} listening on port ${port}`);
});
