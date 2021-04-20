docker build -q -t inr .
docker run --rm --name inr -d -p 8080:8080 -e READ_MEMORY_API=http://localhost:8080/api/v1/debug/readMemory -e WRITE_MEMORY_API=http://localhost:8080/api/v1/debug/writeMemory inr

sleep 5

RESULT=`curl -s --header "Content-Type: application/json" \
  --request POST \
  --data '{"opcode":36,"state":{"a":10,"b":1,"c":66,"d":5,"e":5,"h":255,"l":2,"flags":{"sign":false,"zero":false,"auxCarry":false,"parity":false,"carry":false},"programCounter":1,"stackPointer":2,"cycles":0}}' \
  http://localhost:8080/api/v1/execute`
EXPECTED='{"opcode":36,"state":{"a":10,"b":1,"c":66,"d":5,"e":5,"h":0,"l":2,"flags":{"sign":false,"zero":true,"auxCarry":false,"parity":true,"carry":false},"programCounter":1,"stackPointer":2,"cycles":5}}'

docker kill inr

DIFF=`diff <(jq -S . <<< "$RESULT") <(jq -S . <<< "$EXPECTED")`

if [ $? -eq 0 ]; then
    echo -e "\e[32mINR Test Pass \e[0m"
    exit 0
else
    echo -e "\e[31mINR Test Fail  \e[0m"
    echo "$RESULT"
    echo "$DIFF"
    exit -1
fi