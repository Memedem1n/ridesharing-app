import { BadRequestException, FileTypeValidator, MaxFileSizeValidator, ParseFilePipe } from '@nestjs/common';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { UPLOAD_MAX_BYTES } from './upload.constants';

export const createUploadOptions = (destination: string, allowedMime: RegExp, errorMessage: string) => ({
    storage: diskStorage({
        destination,
        filename: (req, file, cb) => {
            const randomName = Array(32)
                .fill(null)
                .map(() => Math.round(Math.random() * 16).toString(16))
                .join('');
            cb(null, `${randomName}${extname(file.originalname)}`);
        },
    }),
    fileFilter: (req: any, file: Express.Multer.File, cb: (error: Error | null, acceptFile: boolean) => void) => {
        if (!allowedMime.test(file.mimetype)) {
            return cb(new BadRequestException(errorMessage), false);
        }
        cb(null, true);
    },
    limits: { fileSize: UPLOAD_MAX_BYTES },
});

export const createFilePipe = (allowedMime: RegExp) =>
    new ParseFilePipe({
        validators: [
            new MaxFileSizeValidator({ maxSize: UPLOAD_MAX_BYTES }),
            new FileTypeValidator({ fileType: allowedMime }),
        ],
    });
