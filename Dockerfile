FROM maven:3.9.3-eclipse-temurin-17-alpine AS builder

COPY ./src/demo /home

WORKDIR /home

RUN mvn package && cp /home/target/*.jar /enclave.jar

# Enclave image build stage
FROM gramineproject/gramine:latest

RUN apt-get update \
    && apt-get install -y libprotobuf-c1 openjdk-17-jre-headless \
    && apt-get install -y xxd

RUN rm -rf /var/lib/apt/lists/*


COPY --from=builder /enclave.jar /app/
COPY ./src/demo/src/main/resources/demo-file /plaintext/
COPY ./demo.manifest.template /app/
COPY ./entrypoint.sh /app/

RUN mkdir files \
    && gramine-sgx-pf-crypt gen-key -w files/wrap_key

RUN mkdir encrypted \
    && gramine-sgx-pf-crypt encrypt -w files/wrap_key -i plaintext/demo-file -o /encrypted/demo-file-enc.txt

WORKDIR /app

RUN gramine-argv-serializer "/usr/lib/jvm/java-17-openjdk-amd64/bin/java" "-XX:CompressedClassSpaceSize=8m" "-XX:ReservedCodeCacheSize=8m" "-Xmx8m" "-Xms8m" "-jar" "/app/enclave.jar" "/encr>

RUN gramine-sgx-gen-private-key \
    && gramine-manifest -Dlog_level=error -Denc_key=$(xxd -ps /files/wrap_key) -Darch_libdir=/lib/x86_64-linux-gnu demo.manifest.template demo.manifest \
    && gramine-sgx-sign --manifest demo.manifest --output demo.manifest.sgx

ENTRYPOINT ["sh", "entrypoint.sh"]


