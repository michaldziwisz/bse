'use strict';

const environment = process.env.ENVIRONMENT || "development";
const deployment = environment === "deployment";
const production = environment === "production";
const development = environment === "development";
const analyze = process.env.ANALYZE === "true";
const CleanPlugin = require("clean-webpack-plugin");
const CompressionPlugin = require("compression-webpack-plugin");
const HtmlPlugin = require("html-webpack-plugin");
const UglifyJsPlugin = require("uglifyjs-webpack-plugin");
const path = require("path");

const plugins = [];
const babelPlugins = [
  "@babel/plugin-transform-runtime",
  "@babel/plugin-proposal-nullish-coalescing-operator",
  "@babel/plugin-proposal-optional-chaining",
  "@babel/plugin-syntax-dynamic-import",
  "@babel/plugin-transform-destructuring",
  "@babel/plugin-proposal-object-rest-spread",
];

if(!development){
  plugins.push(new CleanPlugin(["data"]));
}

plugins.push(new HtmlPlugin({
  inject: true,
  filename: "index.htm",
  chunks: ["main"],
  minify: {
    collapseWhitespace: !development,
    minifyCSS: !development,
    minifyJS: !development,
    removeComments: !development
  },
  template: "index.htm",
}));

if (!analyze && deployment) {
  plugins.push(new CompressionPlugin({
    deleteOriginalAssets: true,
    test: /\.(html|htm|js|css|ttf|jpeg|jpg|svg|ico|eot)$/,
    filename: "[path][base].gz",
    algorithm: "gzip",
  }));
}

if (analyze) {
  plugins.push(new (require("webpack-bundle-analyzer").BundleAnalyzerPlugin)());
}

module.exports = {
  context: path.resolve(__dirname, "client"),
  mode: development ? "development" : "production",
  entry: {
    main: "./index.jsx",
  },
  resolve: {
    extensions: [".js", ".jsx"],
  },
  devtool: "source-map",
  plugins,
  output: {
    path: path.resolve(__dirname, "data"),
    publicPath: "/",
    filename: deployment ? "[name].js" : "[name].[hash].js",
    chunkFilename: deployment ? "[name].js" : "[name].[hash].js",
  },
  module: {
    rules: [
      {
        test: /\.jsx?$/,
        exclude: /node_modules/,
        use: [{
          loader: "babel-loader",
          options: {
            presets: ["@babel/preset-react", "@babel/preset-env"],
            plugins: babelPlugins
          }
        }]
      },
      {
        test: /\.(gif|png|jpe?g|svg|webp|ico)$/i,
        use: [
          {
            loader: "url-loader",
            options: {
              limit: 10 * 1024,
              noquotes: true,
              fallback: "file-loader",
              name: deployment ? "[name].[ext]" : "images/[name].[hash].[ext]",
            }
          },
          {
            loader: "image-webpack-loader",
            options: {
              bypassOnDebug: true
            }
          }
        ]
      },
      {
        test: /\.css$/i,
        use: [
          "style-loader",
          "css-loader"
        ]
      }
    ]
  },
  optimization: {
    minimizer: [
      new UglifyJsPlugin({
        cache: true,
        parallel: true,
        sourceMap: development
      })
    ]
  }
};
