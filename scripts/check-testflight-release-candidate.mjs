import { readFile } from "node:fs/promises";
import { evaluateTestFlightCandidate } from "./testflight-release-gate.mjs";

const candidatePath = new URL(
  "../config/testflight-release-candidate.json",
  import.meta.url,
);
const candidate = JSON.parse(await readFile(candidatePath, "utf8"));
const postUpload = process.argv.includes("--post-upload");
const result = evaluateTestFlightCandidate(candidate, { postUpload });

process.stdout.write(
  `${JSON.stringify({ candidate: candidate.candidate, postUpload, ...result }, null, 2)}\n`,
);
if (!result.ready) process.exitCode = 2;
