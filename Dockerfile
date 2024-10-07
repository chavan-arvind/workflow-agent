FROM node:16

WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY src/package*.json ./

# Install dependencies
RUN npm install

# Copy source files
COPY src .

# Set the PORT environment variable
ENV PORT=8080

# Expose the port
EXPOSE 8080

# Start the function
CMD [ "npm", "start" ]