# 🚀 WORKSHOP DEVOPS

AWS para Iniciantes, LocalStack, Deploy e Pipeline com GitHub Actions.

## 📌 Público-alvo

Iniciantes em DevOps, estudantes e desenvolvedores que querem aprender o fluxo completo:
desenvolver → testar → empacotar → subir na AWS → automatizar com CI/CD.

## 📌 Pré-requisitos

* Conhecimento básico de programação (qualquer linguagem)
* Git instalado
* Docker instalado
* Conta na AWS (opcional, pois usaremos LocalStack também)

## 🌐 Tutorial de comandos para rodar o NGINX

Para subir um servidor Nginx usando Docker e expô-lo na porta `8080` da sua máquina local:

```bash
docker run --rm -d --name nginx -p 8080:80 nginx:1.28.0
```

Depois disso, ao acessar:

```text
http://localhost:8080
```

Você verá a página padrão do Nginx.

### Como alterar o arquivo `index.html` exibido pelo NGINX

Existem 3 maneiras principais:

#### 1. Usando volume para substituir o `index.html`

Crie um arquivo `index.html` no diretório atual e execute:

```bash
docker run -v $(pwd)/index.html:/usr/share/nginx/html/index.html \
  --rm -d --name nginx -p 8080:80 nginx:1.28.0
```

Assim, o arquivo local será usado como página inicial dentro do container.

#### 2. Editando diretamente dentro do container

Acesse o terminal do container:

```bash
docker exec -it nginx bash
```

Instale um editor de texto:

```bash
apt -y update && apt -y install vim
```

Dentro dele, edite o arquivo em:

```text
/usr/share/nginx/html/index.html
```

#### 3. Copiando um arquivo do computador para dentro do container

Se você preferir alterar localmente e depois enviar para o container:

```bash
docker container cp $(pwd)/index.html nginx:/usr/share/nginx/html
```

## 🪣 Tutorial de upload de arquivos para bucket S3

Este guia mostra como simular a AWS localmente usando LocalStack e fazer upload de arquivos para um bucket S3 com AWS CLI apontando para endpoint local.

### Subindo o LocalStack com Docker

Para iniciar o LocalStack e simular serviços AWS localmente:

```bash
docker run -it -d --name localstack \
  -e LAMBDA_EXECUTOR=docker \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 4566:4566 \
  -p 4510-4559:4510-4559 \
  localstack/localstack:latest
```

### Instalando o AWS CLI (caso ainda não tenha)

Você pode instalar via pip:

```bash
pip install awscli
```

### Configurando o AWS CLI para usar o LocalStack

Antes de tudo, configure credenciais dummy para evitar interagir acidentalmente com uma conta real da AWS:

```bash
aws configure
```

Use valores fictícios, por exemplo:

* AWS Access Key ID: `test`
* AWS Secret Access Key: `test`
* Region: `us-east-1`
* Output: `json`

Agora exporte o endpoint que aponta para o LocalStack:

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
```

### Criando um bucket S3 no LocalStack

Com tudo configurado, crie o bucket:

```bash
aws s3api create-bucket \
  --bucket devopsdays \
  --region us-east-1 \
  --endpoint-url $AWS_ENDPOINT_URL
```

### Fazendo upload de um arquivo para o bucket

Envie o arquivo desejado:

```bash
aws s3 cp ./myfile.txt s3://devopsdays \
  --endpoint-url $AWS_ENDPOINT_URL
```

Se o comando executar sem erros, o arquivo estará dentro do bucket simulado no LocalStack.

Para listar os arquivos do bucket:

```bash
aws s3 ls s3://devopsdays
```

## ⚙️ Tutorial: criar Lambda e acessar via API Gateway

### Criar uma IAM Role para a Lambda

Mesmo que o LocalStack não valide permissões IAM reais, precisamos criar uma role fictícia para que a Lambda seja aceita.

Crie um arquivo `trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Agora crie a role no LocalStack:

```bash
aws iam create-role \
  --role-name lambda-exec-role \
  --assume-role-policy-document file://trust-policy.json
```

Pegue o ARN retornado, algo como:

```text
arn:aws:iam::000000000000:role/lambda-exec-role
```

### Criar a função Lambda com Python 3.12

Crie o arquivo `lambda.py`:

```python
def lambda_handler(event, context):
    print("hello world")

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": "{\"message\": \"It's working!\"}"
    }
```

Compacte o arquivo:

```bash
zip function.zip lambda.py
```

Crie a Lambda:

```bash
aws lambda create-function \
  --function-name apigw-lambda \
  --runtime python3.12 \
  --handler lambda.lambda_handler \
  --memory-size 128 \
  --zip-file fileb://function.zip \
  --role arn:aws:iam::000000000000:role/lambda-exec-role
```

### Criar a REST API

```bash
aws apigateway create-rest-api --name "API Gateway Lambda Integration"
```

Guarde o `REST_API_ID`.

### Obter o recurso raiz `/`

```bash
aws apigateway get-resources --rest-api-id <REST_API_ID>
```

Saída típica:

```json
{
  "items": [
    {
      "id": "u53af9hm83",
      "path": "/"
    }
  ]
}
```

Guarde o `RESOURCE_ID` (id da raiz).

### Criar método GET na raiz `/`

```bash
aws apigateway put-method \
  --rest-api-id <REST_API_ID> \
  --resource-id <RESOURCE_ID> \
  --http-method GET \
  --authorization-type "NONE"
```

### Integrar com a Lambda

```bash
aws apigateway put-integration \
  --rest-api-id <REST_API_ID> \
  --resource-id <RESOURCE_ID> \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:apigw-lambda/invocations \
  --passthrough-behavior WHEN_NO_MATCH
```

### Deploy da API

```bash
aws apigateway create-deployment \
  --rest-api-id <REST_API_ID> \
  --stage-name dev
```

### Invocar a API (na raiz `/`)

Formato oficial:

```bash
curl http://<REST_API_ID>.execute-api.localhost.localstack.cloud:4566/dev/
```

Saída esperada:

```json
{"message": "It's working!"}
```

URL alternativa (caso seu DNS não resolva):

```bash
curl http://localhost:4566/_aws/execute-api/<REST_API_ID>/dev/
```

## 🐳 Build & Push (Docker Hub)

```yaml
name: Build & Publish

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ secrets.DOCKERHUB_USERNAME }}/devopsdays:latest
            ${{ secrets.DOCKERHUB_USERNAME }}/devopsdays:${{ github.sha }}

  deploy:
    name: Deploy to EC2
    runs-on: ubuntu-24.04
    needs: build
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            docker pull ${{ secrets.DOCKERHUB_USERNAME }}/devopsdays:latest
            docker stop devopsdays || true
            docker rm devopsdays || true
            docker run -d \
              --name devopsdays \
              -p 8080:80 \
              --restart unless-stopped \
              ${{ secrets.DOCKERHUB_USERNAME }}/devopsdays:latest
```

## 🎥 Gravação dos comandos no terminal

* https://www.awesomescreenshot.com/video/47283466?key=4290a2972cbb1bad25c1a311debde690
