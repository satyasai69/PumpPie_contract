import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/PoolCore/PoolCore.tact',
    options: {
        debug: true,
    },
};
