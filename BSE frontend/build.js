function build(){
  const configuration = require('./webpack.config');
  const webpack = require('webpack');
  const compiler = webpack(configuration);

  return new Promise((resolve, reject) => {
    compiler.run((error, stats) => {
      if (error) {
        reject({ error, stats });
      } else {
        resolve(stats);
      }
    })
  });
}

function getDisplaySize(size) {
  let sizeKB = size / 1024;
  if (sizeKB >= 1) {
    if (sizeKB < 1024) {
      size = sizeKB.toFixed(2) + ' KB';
    } else {
      size = (sizeKB/1024).toFixed(2) + ' MB';
    }
  } else {
    size = size + ' B';
  }
  let spaces = [];
  spaces.length = 9 - size.length;
  return size + spaces.fill(' ').join('');
}

function describe(stats){
  const assetsData = [];
  const { compilation, startTime, endTime } = stats;
  const { assets, errors, warnings } = compilation;
  const notice = errors.length ?
    ' with errors ' :
    warnings.length ?
      ' with warnings ' :
      ' ';

  console.log(`\n${new Date().toUTCString()}: Build finished${notice}in ${((endTime - startTime) / 1000).toFixed(2)} s\n`);

  if (errors.length) {
    console.log('Build errors:\n');
    errors.forEach(e => console.log(e.message + '\n'));
  }
  if (warnings.length) {
    console.log('Build warnings:\n');
    warnings.forEach(w => console.log(w.message + '\n'));
  }

  for (let key in assets) {
    if (assets.hasOwnProperty(key)) {
      assetsData.push({ key, size: assets[key].size() });
    }
  }
  const bundleSize = getDisplaySize(assetsData.reduce((acc, val) => acc + val.size, 0)).trim();

  console.log(`Produced assets (${bundleSize}):`);
  assetsData
    .sort((a1, a2) => a2.size - a1.size)
    .forEach(a => console.log('\t', getDisplaySize(a.size), a.key));
  console.log();
}

if (module.parent) { // export as a module
  module.exports = build;
} else { // run as cmd application
  const cliArgs = [
    { name: 'environment', alias: 'e', type: String },
    { name: 'analyze', alias: 'a', type: Boolean },
    { name: 'help', alias: 'h', type: Boolean }
  ];
  const options = require('command-line-args')(cliArgs);
  options.environment = options.environment || 'deployment';

  if (options.help) {
    console.log('Build tool available options:');
    cliArgs.filter(arg => !arg.defaultOption).forEach(arg => {
      console.log(`\t-${arg.alias} --${arg.name} [${arg.type.name}${arg.multiple ? '[]' : ''}] ${arg.description || ''}`);
    });
    process.exit(0);
  }

  process.env.ENVIRONMENT = options.environment;
  process.env.ANALYZE = options.analyze;

  console.log(`${new Date().toUTCString()}: Running build for ${options.environment} environment \n`);
  build().then(describe, ({ stats }) => describe(stats));
}
