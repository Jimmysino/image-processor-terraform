const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const crypto = require('crypto');

const s3 = new S3Client({});

const TIPOS_PERMITIDOS = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/gif': 'gif',
  'image/webp': 'webp',
};

exports.handler = async (event) => {
  const body = JSON.parse(event.body);

  if (!body.data) {
    return { statusCode: 400, body: 'Falta la imagen (campo data)' };
  }

  const tipo = body.contentType;
  const imagen = Buffer.from(body.data, 'base64');

  if (!TIPOS_PERMITIDOS[tipo]) {
    return { statusCode: 400, body: 'Formato no permitido. Solo jpg, png, gif o webp' };
  }

  if (imagen.length > 10 * 1024 * 1024) {
    return { statusCode: 413, body: 'La imagen pesa mas de 10 MB' };
  }

  const nombreArchivo = 'uploads/' + crypto.randomUUID() + '.' + TIPOS_PERMITIDOS[tipo];

  await s3.send(new PutObjectCommand({
    Bucket: process.env.S3_BUCKET,
    Key: nombreArchivo,
    Body: imagen,
    ContentType: tipo,
  }));

  return { statusCode: 201, body: 'Imagen subida: ' + nombreArchivo };
};