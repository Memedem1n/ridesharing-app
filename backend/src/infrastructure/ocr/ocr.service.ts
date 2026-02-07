import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { readFile } from 'fs/promises';
import pdfParse from 'pdf-parse';
import { createWorker, Worker } from 'tesseract.js';

@Injectable()
export class OcrService implements OnModuleDestroy {
    private readonly logger = new Logger(OcrService.name);
    private workerPromise: Promise<Worker> | null = null;

    async extractText(filePath: string): Promise<string> {
        if (filePath.toLowerCase().endsWith('.pdf')) {
            return this.extractTextFromPdf(filePath);
        }

        return this.extractTextFromImage(filePath);
    }

    private async extractTextFromImage(filePath: string): Promise<string> {
        const worker = await this.getWorker();
        const { data } = await worker.recognize(filePath);
        return data?.text || '';
    }

    private async extractTextFromPdf(filePath: string): Promise<string> {
        try {
            const buffer = await readFile(filePath);
            const data = await pdfParse(buffer);
            return data?.text || '';
        } catch (error) {
            this.logger.warn(`PDF OCR fallback failed: ${(error as Error).message}`);
            return '';
        }
    }

    private async getWorker(): Promise<Worker> {
        if (!this.workerPromise) {
            const langs = process.env.OCR_LANGS || 'tur+eng';
            this.workerPromise = (async () => {
                const worker = await createWorker(langs);
                return worker;
            })();
        }
        return this.workerPromise;
    }

    async onModuleDestroy() {
        if (this.workerPromise) {
            const worker = await this.workerPromise;
            await worker.terminate();
        }
    }
}
