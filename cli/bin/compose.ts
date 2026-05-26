#!/usr/bin/env node

import { main } from "../index.js";
import { exitWithError } from "../src/utils/errors.js";

main().catch(exitWithError);
