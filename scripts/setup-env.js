const fs = require('fs');
const path = require('path');

if (!fs.existsSync('.env')) {
	const envExamplePath = path.join(__dirname, '..', '.env.example');
	const contents = fs.readFileSync(envExamplePath);
	console.log('Creating .env file in ', path.dirname(__dirname));
	const newEnvFile = contents.toString();
	const envPath = path.join(__dirname, '..', '.env');
	fs.writeFileSync(envPath, newEnvFile);
} else {
	console.log(`A .env file already exist in ${path.dirname(__dirname)}, not modifying it.`);
}
