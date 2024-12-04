import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/core/Factory.tact',
    options: {
        debug: true,
    },
};
