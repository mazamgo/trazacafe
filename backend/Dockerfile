# Imagen para Cloud Run. Se construye desde la raíz del repo porque el
# backend usa el paquete de esquemas del monorepo:
#   gcloud builds submit --tag $IMAGEN --file backend/Dockerfile .
FROM node:24-slim
WORKDIR /srv
COPY package.json package-lock.json ./
COPY schemas/package.json schemas/
COPY backend/package.json backend/
RUN npm ci --omit=dev
COPY schemas schemas
COPY backend backend
ENV NODE_ENV=production
WORKDIR /srv/backend
CMD ["npm", "start"]
