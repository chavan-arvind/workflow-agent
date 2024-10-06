FROM node:16

WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY src/package*.json ./

# Install dependencies
RUN npm install

# Copy source files
COPY src .

# Start the function
CMD [ "npm", "start" ]