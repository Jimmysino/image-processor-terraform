# image-processor-terraform

Ejercicio grupal de Infraestructura como Código. Con Terraform armamos en AWS un procesador de imágenes: se sube una foto, se guarda en S3 y otra función la recorta en un círculo de 40x40. Todo se despliega en tres entornos (dev, qa y prod).

## Integrantes

- Melendez Tapia Jimmy Leito
- Chávez Romero Diego Carlo Jaren
- Aliaga Vasquez Cristian Leonardo
- Lavado Mejía Alvaro Elias
- Banda Orbegoso André Alejandro

## Cómo funciona

1. El cliente hace un POST al API Gateway con un JSON que trae el tipo de imagen y la imagen en base64.
2. La Lambda `upload` revisa que el formato sea jpg, png, gif o webp y que pese menos de 10 MB. Si todo está bien, la guarda en S3 dentro de `uploads/` con un nombre único.
3. S3 avisa a una cola SQS cada vez que llega un archivo nuevo a `uploads/`.
4. La Lambda `crop` lee la cola, descarga la imagen, la achica a 40x40, la recorta en círculo y la guarda como PNG en `processed/`.
5. Si un mensaje falla 3 veces, pasa a una cola de mensajes fallidos (DLQ). Una alarma de CloudWatch vigila esa cola y manda un correo por SNS.

Las Lambdas están en las subredes privadas. Para hablar con S3 y SQS usan endpoints dentro de la VPC, así que no hace falta que salgan a internet.

## Archivos

| Archivo | Qué crea |
|---|---|
| `01-variables.tf`, `terraform.tfvars` | Variables: región, perfil de AWS y correo de alerta por entorno |
| `02-provider.tf` | Provider de AWS y el nombre base de los recursos |
| `03-vpc.tf` | La VPC |
| `04-subnets-publicas.tf` | 2 subredes públicas |
| `05-subnets-privadas.tf` | 2 subredes privadas |
| `06-nat-gateways.tf` | NAT Gateways |
| `07-rutas-privadas.tf` | Rutas de las subredes privadas |
| `08-s3.tf` | Bucket de imágenes |
| `09-endpoint-s3.tf` | Endpoint de S3 |
| `10-iam-upload.tf`, `11-sg-upload.tf`, `12-lambda-upload.tf` | Lambda `upload` con su rol y su security group |
| `13-api-gateway.tf` | API Gateway que recibe la imagen |
| `14-sqs.tf` | Cola principal, DLQ y permiso para que S3 escriba en la cola |
| `15-s3-notificacion.tf` | Aviso de S3 a la cola |
| `16-endpoint-sqs.tf` | Endpoint de SQS y sus reglas |
| `17-alarma.tf` | Tema SNS, correo y alarma de la DLQ |
| `18-iam-crop.tf`, `19-sg-crop.tf`, `20-lambda-crop.tf` | Lambda `crop`, su rol, su security group y el disparador desde la cola |
| `src/upload`, `src/crop` | Código de las dos Lambdas |

## Entornos

Usamos workspaces de Terraform (`dev`, `qa` y `prod`). El nombre de cada recurso lleva el entorno, así que no se pisan entre sí. El correo de alerta de cada uno se define en `terraform.tfvars`.

Cada entorno usa 2 IPs elásticas y AWS deja 5 por región, por eso se despliega y se destruye uno a la vez.

## Cómo desplegar

Se necesita Git, Terraform, Node.js y la AWS CLI con el perfil configurado:

```bash
aws configure --profile proyecto-tf
```

Después:

```bash
git clone https://github.com/Jimmysino/image-processor-terraform.git
cd image-processor-terraform

cd src/crop
npm install --os=linux --cpu=x64
cd ../..

terraform init
terraform workspace new dev
terraform apply
```

El `--os=linux --cpu=x64` es necesario aunque se esté en Windows o Mac, porque la librería `sharp` tiene que ser la versión de Linux que usa Lambda.

Para qa y prod se repite con `terraform workspace new qa` (o `prod`) y `terraform apply`. Cuando termina, `terraform output` muestra `api_url` y `bucket`.

AWS manda un correo de SNS y hay que confirmar la suscripción. Si no se confirma, la alarma no avisa.

## Cómo probar

En PowerShell, con una `foto.jpg` de menos de 4 MB en la carpeta:

```powershell
$URL = terraform output -raw api_url
$BUCKET = terraform output -raw bucket

$data = [Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\foto.jpg"))
$body = @{ contentType = "image/jpeg"; data = $data } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri $URL -ContentType "application/json" -Body $body
```

Debe responder `Imagen subida: uploads/...`. Después de unos 20 segundos se revisa el bucket:

```powershell
aws s3 ls "s3://$BUCKET/uploads/" --profile proyecto-tf
aws s3 ls "s3://$BUCKET/processed/" --profile proyecto-tf
```

Para ver el resultado se descarga el archivo `..._circular.png` con `aws s3 cp`.

Para probar un formato no permitido:

```powershell
$body = @{ contentType = "text/plain"; data = "aG9sYQ==" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri $URL -ContentType "application/json" -Body $body
```

Tiene que responder con error 400.

## Decisiones

- **JSON con base64 y no multipart.** Elegimos base64 porque la Lambda solo necesita `JSON.parse` y `Buffer.from`, sin librerías extra, y es fácil de probar desde la terminal. La desventaja es que la imagen pesa cerca de 33 % más, y como Lambda acepta máximo 6 MB por petición, en la práctica las imágenes deben pesar menos de 4 MB.
- **Subredes privadas con NAT.** Las Lambdas no tienen IP pública, solo salen a internet por los NAT Gateways.
- **Endpoints de S3 y SQS.** El tráfico a esos servicios va por dentro de la VPC.
- **DLQ y alarma.** Si una imagen no se puede procesar después de 3 intentos, no se pierde: queda en la DLQ y llega un correo.
- **Fallos por mensaje.** La Lambda `crop` devuelve solo los mensajes que fallaron, así que si uno de un grupo de 5 falla, los otros no se repiten.

## Costo

Un entorno encendido cuesta cerca de USD 0.12 por hora, casi todo por los 2 NAT Gateways, el endpoint de SQS y las IPs elásticas. Lo demás cuesta centavos con pocas pruebas. Hay que destruir al terminar para no dejar cobros.

## Destruir

Entorno por entorno:

```bash
terraform workspace select dev
terraform destroy
terraform state list
```

Después del destroy, `terraform state list` debe salir vacío.

