import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/Jetton/JettonCore.tact',
    options: {
        debug: true,
    },
};
