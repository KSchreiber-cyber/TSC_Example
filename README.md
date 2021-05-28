# KPMG Origins
his project was bootstrapped with lerna manager

Prerequisites:
VS Code with extensions:
TSLint
Code Spell Checker
vscode-icons
vscode-styled-components
Docker
Chrome with extensions:
Redux DevTools
(Optional) React Developer Tools
nvm
yarn
*Optional:
add localhost to the list of domains to bypass by Web Proxy in the Network settings
After cloning repo:
nvm use (to select the required version)
npm i -g lerna
lerna bootstrap (to download and prepare the environment)
yarn install
To run the app locally:
Run: yarn go
To test with the back-end running locally, change API_PORT to 5000 in packages/kpmgorigins-uisrc/setupProxy.js and run yarn go again

Available Scripts
In the project directory, you can run:

yarn go
Starts storybook, build watch of storybook and kpmgorigins-ui at the same time so any changes to storybooks or kpmgorigins-ui cause automatic UI refresh making it the best dev experience.

yarn kpmgorigins-ui
Runs the app in the development mode.
Open http://localhost:3000  to view it in the browser.

The page will reload if you make edits.
You will also see any lint errors in the console.

yarn storybook
Runs the storybook in the development mode.
Open http://localhost:6000  to view it in the browser.

yarn build:lib:watch
Starts build watch, so when you are also running kpmgorigins-ui and storybook, any changes to kpmgorigins-lib components will cause automatic UI refresh.

yarn build
Builds the app for production to the build folder.
It correctly bundles React in production mode and optimizes the build for the best performance.

The build is minified and the filenames include the hashes.
