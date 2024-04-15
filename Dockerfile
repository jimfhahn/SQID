# build stage
FROM node:14 AS build-stage

# make sure the package repository is up to date and upgrade all the installed packages
RUN apt-get update && apt-get upgrade -y

# make the 'app' folder the current working directory
WORKDIR /app

# copy both 'package.json' and 'package-lock.json' (if available)
COPY package*.json ./

# install project dependencies
RUN npm ci

# copy project files and folders to the current working directory (i.e. 'app' folder)
COPY . .

# set environment variables
ENV VUE_APP_I18N_LOCALE=en
ENV VUE_APP_I18N_FALLBACK_LOCALE=en

# build app for production with minification
RUN npm run build

# production stage
FROM nginx:stable-alpine AS production-stage

# copy the built app to the nginx directory
COPY --from=build-stage /app/dist /usr/share/nginx/html/sqid/sqid-ng

# copy the nginx configuration file
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]