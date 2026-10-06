const { S3Client, GetObjectCommand, PutObjectCommand } = require('@aws-sdk/client-s3');
const sharp = require('sharp');

const s3 = new S3Client({});

const circulo = Buffer.from(
    '<svg width="40" height="40"><circle cx="20" cy="20" r="20" fill="white"/></svg>'
);

exports.handler = async (event) => {
    const fallidos = [];

    for (const mensaje of event.Records) {
        try {
            const aviso = JSON.parse(mensaje.body);

            if (!aviso.Records) {
                continue;
            }

            const original = aviso.Records[0].s3.object.key;

            const respuesta = await s3.send(new GetObjectCommand({
                Bucket: process.env.S3_BUCKET,
                Key: original,
            }));
            const imagen = await respuesta.Body.transformToByteArray();

            const recortada = await sharp(imagen)
                .resize(40, 40)
                .composite([{ input: circulo, blend: 'dest-in' }])
                .png()
                .toBuffer();

            const nombre = original.replace('uploads/', '').split('.')[0];

            await s3.send(new PutObjectCommand({
                Bucket: process.env.S3_BUCKET,
                Key: 'processed/' + nombre + '_circular.png',
                Body: recortada,
                ContentType: 'image/png',
            }));

            console.log('Procesada: ' + original);
        } catch (error) {
            console.error(error);
            fallidos.push({ itemIdentifier: mensaje.messageId });
        }
    }

    return { batchItemFailures: fallidos };
};