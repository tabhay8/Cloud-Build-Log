# Build from the REPOSITORY ROOT, not from migration/:
#   az acr build -r <acr> -t cbl-migrate:<sha> -f migration/Dockerfile .
# The root context is what lets the image copy db/init.sql, so the job applies
# the same schema file the local SQL container does. One schema, one source.

FROM mcr.microsoft.com/cbl-mariner/base/nodejs:18
WORKDIR /app

COPY migration/package.json migration/package-lock.json* ./
RUN npm install --omit=dev

COPY migration/migrate.js ./migrate.js
COPY migration/sql/seed.sql ./sql/seed.sql
COPY db/init.sql ./sql/init.sql

USER 1000
CMD ["node", "migrate.js"]
