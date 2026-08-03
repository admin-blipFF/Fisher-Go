const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const { chromium } = require('playwright');

const defaultBootstrapBudgetBytes = 15 * 1024 * 1024;

function paethPredictor(left, above, upperLeft) {
  const estimate = left + above - upperLeft;
  const leftDistance = Math.abs(estimate - left);
  const aboveDistance = Math.abs(estimate - above);
  const upperLeftDistance = Math.abs(estimate - upperLeft);
  if (leftDistance <= aboveDistance && leftDistance <= upperLeftDistance) {
    return left;
  }
  if (aboveDistance <= upperLeftDistance) return above;
  return upperLeft;
}

function decodePng(buffer) {
  if (buffer.readUInt32BE(0) !== 0x89504e47) {
    throw new Error('Screenshot is not a PNG');
  }
  let offset = 8;
  let width;
  let height;
  let bitDepth;
  let colorType;
  const idat = [];
  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString('ascii', offset + 4, offset + 8);
    const data = buffer.subarray(offset + 8, offset + 8 + length);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
    } else if (type === 'IDAT') {
      idat.push(data);
    }
    offset += 12 + length;
    if (type === 'IEND') break;
  }
  if (bitDepth !== 8 || ![2, 6].includes(colorType)) {
    throw new Error(`Unsupported PNG format: bitDepth=${bitDepth}, colorType=${colorType}`);
  }
  const channels = colorType === 6 ? 4 : 3;
  const stride = width * channels;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const pixels = Buffer.alloc(width * height * channels);
  let rawOffset = 0;
  let pixelOffset = 0;
  let previous = Buffer.alloc(stride);
  for (let y = 0; y < height; y += 1) {
    const filter = raw[rawOffset++];
    const current = Buffer.alloc(stride);
    for (let x = 0; x < stride; x += 1) {
      const left = x >= channels ? current[x - channels] : 0;
      const above = previous[x];
      const upperLeft = x >= channels ? previous[x - channels] : 0;
      const value = raw[rawOffset++];
      if (filter === 0) current[x] = value;
      else if (filter === 1) current[x] = (value + left) & 0xff;
      else if (filter === 2) current[x] = (value + above) & 0xff;
      else if (filter === 3) current[x] = (value + Math.floor((left + above) / 2)) & 0xff;
      else if (filter === 4) current[x] = (value + paethPredictor(left, above, upperLeft)) & 0xff;
      else throw new Error(`Unsupported PNG filter: ${filter}`);
    }
    current.copy(pixels, pixelOffset);
    pixelOffset += stride;
    previous = current;
  }
  return {width, height, channels, pixels};
}

function inspectMapScreenshot(buffer) {
  const image = decodePng(buffer);
  const xStart = Math.floor(image.width * 0.04);
  const xEnd = Math.floor(image.width * 0.90);
  const yStart = Math.floor(image.height * 0.25);
  const yEnd = Math.floor(image.height * 0.85);
  const colors = new Set();
  const channels = [];
  const samples = [];
  for (let row = 0; row < 8; row += 1) {
    const sampleRow = [];
    for (let column = 0; column < 12; column += 1) {
      const x = Math.min(image.width - 1, xStart + Math.floor((xEnd - xStart) * (column + 0.5) / 12));
      const y = Math.min(image.height - 1, yStart + Math.floor((yEnd - yStart) * (row + 0.5) / 8));
      const offset = (y * image.width + x) * image.channels;
      const pixel = [image.pixels[offset], image.pixels[offset + 1], image.pixels[offset + 2]];
      colors.add(pixel.join(','));
      channels.push(...pixel);
      sampleRow.push(pixel);
    }
    samples.push(sampleRow);
  }
  let adjacentComparisons = 0;
  let adjacentChanges = 0;
  for (let row = 0; row < samples.length; row += 1) {
    for (let column = 0; column < samples[row].length; column += 1) {
      const current = samples[row][column];
      const neighbors = [];
      if (column + 1 < samples[row].length) neighbors.push(samples[row][column + 1]);
      if (row + 1 < samples.length) neighbors.push(samples[row + 1][column]);
      for (const neighbor of neighbors) {
        adjacentComparisons += 1;
        const distance = Math.abs(current[0] - neighbor[0]) +
          Math.abs(current[1] - neighbor[1]) +
          Math.abs(current[2] - neighbor[2]);
        if (distance >= 18) adjacentChanges += 1;
      }
    }
  }
  const sampleColorCounts = new Map();
  for (const row of samples) {
    for (const pixel of row) {
      const key = pixel.join(',');
      sampleColorCounts.set(key, (sampleColorCounts.get(key) ?? 0) + 1);
    }
  }
  const dominantSampleCount = Math.max(...sampleColorCounts.values());
  const colorRange = Math.max(...channels) - Math.min(...channels);
  return {
    width: image.width,
    height: image.height,
    sampled_pixels: channels.length / 3,
    distinct_colors: colors.size,
    color_range: colorRange,
    adjacent_change_ratio: adjacentComparisons === 0 ? 0 : Number((adjacentChanges / adjacentComparisons).toFixed(4)),
    dominant_sample_ratio: Number((dominantSampleCount / (samples.length * samples[0].length)).toFixed(4)),
    populated: colors.size >= 8 && colorRange >= 24,
  };
}

function readGoldenManifest(manifestPath) {
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`Web map golden manifest not found: ${manifestPath}`);
  }
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  if (!manifest.viewports || typeof manifest.viewports !== 'object') {
    throw new Error('Web map golden manifest must define viewports');
  }
  return manifest;
}

function verifyGoldenVisualProof(mapVisualProof, viewportValue, golden, tileResponses) {
  const expected = golden.viewports[viewportValue];
  if (!expected) {
    return {
      passed: false,
      violations: [`no golden entry for ${viewportValue}`],
    };
  }
  const violations = [];
  if (mapVisualProof.width !== expected.width || mapVisualProof.height !== expected.height) {
    violations.push(`screenshot dimensions ${mapVisualProof.width}x${mapVisualProof.height} do not match ${expected.width}x${expected.height}`);
  }
  if (mapVisualProof.distinct_colors < expected.min_distinct_colors) {
    violations.push(`distinct colors ${mapVisualProof.distinct_colors} < ${expected.min_distinct_colors}`);
  }
  if (mapVisualProof.color_range < expected.min_color_range) {
    violations.push(`color range ${mapVisualProof.color_range} < ${expected.min_color_range}`);
  }
  if (mapVisualProof.adjacent_change_ratio < expected.min_adjacent_change_ratio) {
    violations.push(`adjacent change ratio ${mapVisualProof.adjacent_change_ratio} < ${expected.min_adjacent_change_ratio}`);
  }
  if (mapVisualProof.dominant_sample_ratio > expected.max_dominant_sample_ratio) {
    violations.push(`dominant sample ratio ${mapVisualProof.dominant_sample_ratio} > ${expected.max_dominant_sample_ratio}`);
  }
  if (expected.required_tile_host && !tileResponses.some((response) =>
    response.status === 200 && response.url.includes(expected.required_tile_host))) {
    violations.push(`no successful tile response from ${expected.required_tile_host}`);
  }
  return {
    passed: violations.length === 0,
    violations,
    expected,
  };
}

function readArgs(argv) {
  const values = {
    url: 'http://127.0.0.1:4173/',
    script: 'tool/web_map_benchmark.js',
    output: 'tmp/web-map-benchmark.json',
    minFps: 30,
    maxP95FrameMs: 33.333,
    maxJankyRate: 0.05,
    bootstrapScript: 'tool/web_bootstrap_capture.js',
    bootstrapBudgetBytes: defaultBootstrapBudgetBytes,
    enforceBootstrapBudget: false,
    enforce: false,
    viewports: ['390x844', '1440x900'],
    goldenManifest: 'test/goldens/game_map/manifest.json',
  };

  for (const arg of argv) {
    if (arg === '--enforce-frame-budget') {
      values.enforce = true;
      continue;
    }
    if (arg === '--enforce-bootstrap-budget') {
      values.enforceBootstrapBudget = true;
      continue;
    }
    const separator = arg.indexOf('=');
    if (separator === -1) continue;
    const key = arg.slice(0, separator);
    const value = arg.slice(separator + 1);
    if (key === '--url') values.url = value;
    if (key === '--script') values.script = value;
    if (key === '--bootstrap-script') values.bootstrapScript = value;
    if (key === '--bootstrap-budget-mib') {
      values.bootstrapBudgetBytes = Number(value) * 1024 * 1024;
    }
    if (key === '--output') values.output = value;
    if (key === '--min-fps') values.minFps = Number(value);
    if (key === '--max-p95-frame-ms') values.maxP95FrameMs = Number(value);
    if (key === '--max-janky-rate') values.maxJankyRate = Number(value);
    if (key === '--viewport') values.viewports = value.split(',');
    if (key === '--golden-manifest') values.goldenManifest = value;
  }
  return values;
}

function parseViewport(value) {
  const match = /^(\d+)x(\d+)$/.exec(value);
  if (!match) throw new Error(`Invalid viewport: ${value}`);
  return {width: Number(match[1]), height: Number(match[2])};
}

function benchmarkFunction(scriptPath) {
  const source = fs.readFileSync(scriptPath, 'utf8');
  const run = eval(source);
  if (typeof run !== 'function') {
    throw new Error(`${scriptPath} must evaluate to an async page function`);
  }
  return run;
}

function bootstrapMetricsFromTitle(title) {
  const prefix = 'FisherGO_WEB_BOOTSTRAP:';
  if (!title.startsWith(prefix)) {
    throw new Error(`Bootstrap page did not publish ${prefix}`);
  }
  return JSON.parse(title.slice(prefix.length));
}

function bootstrapBudgetForCapture(capture, options) {
  const initialBytes = Number(capture.initial_2s_bytes) || 0;
  const lazyFishBytes = Number(capture.initial_2s_fish_media_bytes) || 0;
  const measuredBytes = Math.max(0, initialBytes - lazyFishBytes);
  const violations = [];
  if (measuredBytes > options.bootstrapBudgetBytes) {
    violations.push(
      `initial transfer excluding lazy fish media ${(
        measuredBytes / (1024 * 1024)
      ).toFixed(2)} MiB > ${(options.bootstrapBudgetBytes / (1024 * 1024)).toFixed(2)} MiB`,
    );
  }
  return {
    initial_2s_bytes: initialBytes,
    initial_2s_fish_media_bytes: lazyFishBytes,
    measured_bytes_excluding_lazy_fish: measuredBytes,
    budget_bytes: options.bootstrapBudgetBytes,
    violations,
    passed: violations.length === 0,
  };
}

function metricsFromTitle(title) {
  const prefix = 'FisherGO_WEB_BENCHMARK:';
  if (!title.startsWith(prefix)) {
    throw new Error(`Benchmark page did not publish ${prefix}`);
  }
  return JSON.parse(title.slice(prefix.length));
}

function violationsFor(metrics, options) {
  const violations = [];
  if (metrics.fps < options.minFps) {
    violations.push(`FPS ${metrics.fps} < ${options.minFps}`);
  }
  if (metrics.p95_frame_ms > options.maxP95FrameMs) {
    violations.push(
      `p95 ${metrics.p95_frame_ms} ms > ${options.maxP95FrameMs} ms`,
    );
  }
  if (metrics.janky_rate > options.maxJankyRate) {
    violations.push(
      `janky rate ${metrics.janky_rate} > ${options.maxJankyRate}`,
    );
  }
  return violations;
}

async function main() {
  const options = readArgs(process.argv.slice(2));
  const runBenchmark = benchmarkFunction(options.script);
  const runBootstrapCapture = benchmarkFunction(options.bootstrapScript);
  const outputPath = path.resolve(options.output);
  const goldenManifest = readGoldenManifest(path.resolve(options.goldenManifest));
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  fs.mkdirSync(path.resolve('output/playwright'), {recursive: true});

  const browser = await chromium.launch({headless: true});
  const results = [];
  const failures = [];
  const bootstrapBudgets = new Map();
  try {
    const bootstrapViewport = parseViewport(options.viewports[0]);
    const bootstrapContext = await browser.newContext({
      viewport: bootstrapViewport,
      geolocation: {
        latitude: 22.3819,
        longitude: 114.1874,
        accuracy: 15,
      },
      permissions: ['geolocation'],
    });
    const bootstrapPage = await bootstrapContext.newPage();
    try {
      await bootstrapPage.goto(options.url, {
        waitUntil: 'domcontentloaded',
        timeout: 60000,
      });
      await runBootstrapCapture(bootstrapPage);
      const bootstrap = bootstrapMetricsFromTitle(await bootstrapPage.title());
      for (const capture of bootstrap.captures ?? []) {
        if (options.viewports.includes(capture.viewport)) {
          bootstrapBudgets.set(
            capture.viewport,
            bootstrapBudgetForCapture(capture, options),
          );
        }
      }
    } finally {
      await bootstrapContext.close();
    }

    for (const viewportValue of options.viewports) {
      const viewport = parseViewport(viewportValue);
      const bootstrapBudget = bootstrapBudgets.get(viewportValue);
      if (!bootstrapBudget) {
        throw new Error(`Bootstrap capture missing viewport ${viewportValue}`);
      }
      if (options.enforceBootstrapBudget && !bootstrapBudget.passed) {
        failures.push(
          `${viewportValue}: ${bootstrapBudget.violations.join('; ')}`,
        );
      }

      const context = await browser.newContext({
        viewport,
        // Keep the map proof deterministic and avoid racing browser location
        // permission with the five-second motion window.
        geolocation: {
          latitude: 22.3819,
          longitude: 114.1874,
          accuracy: 15,
        },
        permissions: ['geolocation'],
      });
      const page = await context.newPage();
      try {
        await page.goto(options.url, {
          waitUntil: 'domcontentloaded',
          timeout: 60000,
        });
        await runBenchmark(page);
        const metrics = metricsFromTitle(await page.title());
        const screenshot = path.resolve(
          'output/playwright',
          `web-map-proof-${viewportValue}.png`,
        );
        fs.copyFileSync(
          path.resolve('output/playwright/web-map-proof-benchmark.png'),
          screenshot,
        );
        const mapVisualProof = inspectMapScreenshot(
          fs.readFileSync(screenshot),
        );
        metrics.map_visual_proof = mapVisualProof;
        const goldenVisualProof = verifyGoldenVisualProof(
          mapVisualProof,
          viewportValue,
          goldenManifest,
          metrics.tile_responses ?? [],
        );
        metrics.golden_visual_proof = goldenVisualProof;
        const violations = violationsFor(metrics, options);
        metrics.bootstrap_budget = bootstrapBudget;
        metrics.bootstrap_budget_passed = bootstrapBudget.passed;
        if (!mapVisualProof.populated) {
          violations.push('map visual proof is not populated');
        }
        if (!goldenVisualProof.passed) {
          violations.push(...goldenVisualProof.violations.map((violation) => `visual golden: ${violation}`));
        }
        results.push({
          ...metrics,
          screenshot,
          frame_budget_violations: violations,
        });
        if (options.enforce && violations.length > 0) {
          failures.push(`${viewportValue}: ${violations.join('; ')}`);
        }
        if (!mapVisualProof.populated) {
          failures.push(`${viewportValue}: map visual proof is not populated`);
        }
        if (!goldenVisualProof.passed) {
          failures.push(`${viewportValue}: ${goldenVisualProof.violations.join('; ')}`);
        }
      } finally {
        await context.close();
      }
    }
  } finally {
    await browser.close();
  }

  const report = {
    benchmark: 'FisherGO web map',
    generated_at: new Date().toISOString(),
    url: options.url,
    enforcement: {
      enabled: options.enforce,
      min_fps: options.minFps,
      max_p95_frame_ms: options.maxP95FrameMs,
      max_janky_rate: options.maxJankyRate,
      bootstrap_budget_enabled: options.enforceBootstrapBudget,
      bootstrap_budget_bytes: options.bootstrapBudgetBytes,
    },
    results,
    frame_budget_passed: results.every(
      (result) => result.frame_budget_violations.length === 0,
    ),
    bootstrap_budget_passed: results.every(
      (result) => result.bootstrap_budget_passed,
    ),
  };
  fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));
  if (failures.length > 0) {
    throw new Error(`Web frame budget failed: ${failures.join(' | ')}`);
  }
}

main().catch((error) => {
  console.error(error.stack || error);
  process.exitCode = 1;
});
