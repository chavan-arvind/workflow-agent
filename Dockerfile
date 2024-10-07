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

# Add debugging
RUN echo "Node version: $(node -v)"
RUN echo "NPM version: $(npm -v)"
RUN ls -la

# Start the function
CMD ["sh", "-c", "echo 'Starting server on port $PORT' && npm start"]