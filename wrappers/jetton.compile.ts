import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/Jetton/jetton.tact',
    options: {
        debug: true,
    },
};
