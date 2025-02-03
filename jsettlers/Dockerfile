FROM openjdk:8-jre

ENV DISPLAY 127.0.0.1:0

WORKDIR /workdir
RUN wget http://nand.net/jsettlers/JSettlers.jar
RUN apt update && apt install -y libxtst6 libxrender1

CMD ["java", "-jar", "JSettlers.jar"]
