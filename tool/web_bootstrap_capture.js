async (page) => {
  const initialWindowMs = 2000;
  const totalWindowMs = 10000;
  const viewports = [
    {width: 390, height: 844},
    {width: 1440, height: 900},
  ];
  const currentUrl = page.url();
  const captureUrl = /^https?:\/\//.test(currentUrl)
      ? currentUrl
      : 'http://localhost:4173/';
  const targetOrigin = captureUrl.match(/^(https?:\/\/[^/]+)/)?.[1]
      ?? 'http://localhost:4173';
  const targetPathPrefix = `${targetOrigin}/`;
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Network.enable');
  await cdp.send('Network.setCacheDisabled', {cacheDisabled: true});

  const asBytes = (value) => {
    const number = Number(value);
    return Number.isFinite(number) && number > 0 ? number : 0;
  };

  async function captureViewport(viewport) {
    await page.setViewportSize(viewport);
    const requests = new Map();
    const captureStartedAt = Date.now();
    const elapsedMs = () => Date.now() - captureStartedAt;
    const requestFor = (requestId) => requests.get(requestId);
    const onRequest = (event) => {
      const url = event.request?.url ?? '';
      if (!url.startsWith(targetPathPrefix)) return;
      requests.set(event.requestId, {
        request_id: event.requestId,
        url: url.slice(targetOrigin.length),
        status: 0,
        type: event.type ?? 'Other',
        started_ms: elapsedMs(),
        bytes_received: 0,
        finished: false,
        failed: false,
      });
    };
    const onResponse = (event) => {
      const request = requestFor(event.requestId);
      if (!request) return;
      request.status = event.response?.status ?? request.status;
      request.type = event.type ?? request.type;
    };
    const onData = (event) => {
      const request = requestFor(event.requestId);
      if (!request) return;
      request.bytes_received += asBytes(event.encodedDataLength);
    };
    const onFinished = (event) => {
      const request = requestFor(event.requestId);
      if (!request) return;
      request.finished = true;
      request.finished_ms = elapsedMs();
      request.bytes_received = Math.max(
        request.bytes_received,
        asBytes(event.encodedDataLength),
      );
    };
    const onFailed = (event) => {
      const request = requestFor(event.requestId);
      if (!request) return;
      request.failed = true;
      request.finished_ms = elapsedMs();
    };

    cdp.on('Network.requestWillBeSent', onRequest);
    cdp.on('Network.responseReceived', onResponse);
    cdp.on('Network.dataReceived', onData);
    cdp.on('Network.loadingFinished', onFinished);
    cdp.on('Network.loadingFailed', onFailed);

    const navigation = page.goto(captureUrl, {waitUntil: 'domcontentloaded'});
    await page.waitForTimeout(initialWindowMs);
    const atTwoSeconds = Array.from(requests.values()).map((request) => ({
      request_id: request.request_id,
      bytes_received: request.bytes_received,
      in_flight: !request.finished && !request.failed,
    }));
    const atTwoSecondsById = new Map(
      atTwoSeconds.map((request) => [request.request_id, request]),
    );

    await navigation;
    await page.waitForTimeout(Math.max(0, totalWindowMs - elapsedMs()));

    cdp.off('Network.requestWillBeSent', onRequest);
    cdp.off('Network.responseReceived', onResponse);
    cdp.off('Network.dataReceived', onData);
    cdp.off('Network.loadingFinished', onFinished);
    cdp.off('Network.loadingFailed', onFailed);

    const capturedRequests = Array.from(requests.values()).map((request) => {
      const snapshot = atTwoSecondsById.get(request.request_id);
      return {
        request_id: request.request_id,
        url: request.url,
        status: request.status,
        type: request.type,
        bytes: request.bytes_received,
        bytes_received_at_2s: snapshot?.bytes_received ?? 0,
        in_flight_at_2s: snapshot?.in_flight ?? false,
        started_ms: request.started_ms,
        completed_elapsed_ms: request.finished_ms ?? null,
        failed: request.failed,
      };
    });
    const startedByTwoSeconds = capturedRequests.filter(
      (item) => item.started_ms <= initialWindowMs,
    );
    const completedByTwoSeconds = startedByTwoSeconds.filter(
      (item) => item.completed_elapsed_ms !== null &&
          item.completed_elapsed_ms <= initialWindowMs,
    );
    const sum = (items, key) => items.reduce(
      (total, item) => total + (Number(item[key]) || 0),
      0,
    );
    const totalBytes = sum(capturedRequests, 'bytes');
    const initialBytes = sum(startedByTwoSeconds, 'bytes_received_at_2s');
    const fishMediaPath = (item) =>
        item.url.includes('/assets/fish/mobile_webp/') ||
        item.url.includes('/assets/fish/mobile/');

    return {
      viewport: `${viewport.width}x${viewport.height}`,
      initial_window_ms: initialWindowMs,
      total_window_ms: totalWindowMs,
      initial_2s_bytes: initialBytes,
      initial_2s_completed_bytes: sum(completedByTwoSeconds, 'bytes'),
      initial_2s_in_flight_bytes: sum(
        startedByTwoSeconds.filter((item) => item.in_flight_at_2s),
        'bytes_received_at_2s',
      ),
      total_bytes: totalBytes,
      initial_2s_request_count: startedByTwoSeconds.length,
      initial_2s_completed_request_count: completedByTwoSeconds.length,
      initial_2s_in_flight_request_count: startedByTwoSeconds.filter(
        (item) => item.in_flight_at_2s,
      ).length,
      total_request_count: capturedRequests.length,
      fish_media_bytes: sum(capturedRequests.filter(fishMediaPath), 'bytes'),
      deferred_bytes: Math.max(0, totalBytes - initialBytes),
      requests: capturedRequests,
    };
  }

  const captures = [];
  for (const viewport of viewports) {
    captures.push(await captureViewport(viewport));
  }

  const result = {
    cache_disabled: true,
    capture_url: captureUrl,
    targetOrigin,
    captures,
  };

  await page.evaluate((value) => {
    document.title = `FisherGO_WEB_BOOTSTRAP:${JSON.stringify(value)}`;
  }, result);
  await page.screenshot({path: 'output/playwright/web-bootstrap.png'});
}
