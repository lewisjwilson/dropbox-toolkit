# Use the specific Node.js v20.14.0 image as the base image
FROM node:20.14.0

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json to the container
COPY package*.json ./

# Install the dependencies
RUN npm install

# Copy the rest of the application files
COPY . .

# Build the Vue application
RUN npm run build

# Expose the port that the app runs on (change this if your app runs on a different port)
EXPOSE 3000
