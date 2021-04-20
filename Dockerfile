FROM crystallang/crystal:1.0.0-alpine AS build

WORKDIR /app

COPY shard.lock shard.yml ./
RUN shards install
COPY src/ src/
RUN crystal build --release --static src/inr.cr

FROM alpine:3.13.5

COPY --from=build /app/inr .

EXPOSE 3000

ENTRYPOINT [ "./inr" ]