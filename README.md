# image-processor-terraform
Ejercicio grupal de Infraestructura como Código. (dev, qa y prod)
## Integrantes

- Melendez Tapia Jimmy Leito
- Chávez Romero Diego Carlo Jaren
- Aliaga Vasquez Cristian Leonardo
- Lavado Mejía Alvaro Elias
- Banda Orbegoso André Alejandro

## Como desplegar

terraform init
terraform workspace new dev   # (igual con qa y prod)
terraform workspace select dev
terraform plan
terraform apply

## Como destruir

terraform workspace select dev
terraform destroy

## Antes de desplegar

cd src/crop
npm install --os=linux --cpu=x64
cd ../..

## Subida

$URL = terraform output -raw api_url
$data = [Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\foto.jpg"))
$body = @{ contentType = "image/jpeg"; data = $data } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri $URL -ContentType "application/json" -Body $body
aws s3 ls "s3://$(terraform output -raw bucket)/uploads/" --profile proyecto-tf

