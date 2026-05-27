#!/usr/bin/env node

import { main } from "../index.ts";
import { exitWithError } from "../src/utils/errors.ts";

main().catch(exitWithError);
