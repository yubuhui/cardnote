import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

/**
 * WebDAV 文件/文件夹信息
 */
export interface WebDAVItem {
  name: string;
  path: string;
  isDirectory: boolean;
  size: number;
  lastModified: string;
  contentType: string;
}

/** sendRequest 可选参数 */
class SendRequestOptions {
  body?: string | ArrayBuffer;
  contentType?: string;
  extraHeaders?: Record<string, string>;

  constructor(body?: string | ArrayBuffer, contentType?: string, extraHeaders?: Record<string, string>) {
    this.body = body;
    this.contentType = contentType;
    this.extraHeaders = extraHeaders;
  }
}

/**
 * WebDAV 协议客户端
 * 基于 @ohos.net.http 实现的纯 HTTP WebDAV 客户端，支持 Basic Auth
 */
export class WebDAVClient {
  private baseUrl: string;
  private username: string;
  private password: string;
  private authHeader: string;

  /**
   * @param baseUrl WebDAV 服务器根路径，如 https://dav.example.com/kanjisync/
   * @param username 用户名
   * @param password 密码
   */
  constructor(baseUrl: string, username: string, password: string) {
    this.baseUrl = baseUrl.endsWith('/') ? baseUrl : baseUrl + '/';
    this.username = username;
    this.password = password;

    // 生成 Basic Auth 头部
    const credentials: string = `${username}:${password}`;
    const textEncoder: util.TextEncoder = new util.TextEncoder();
    const bytes: Uint8Array = textEncoder.encodeInto(credentials);
    const base64: util.Base64Helper = new util.Base64Helper();
    const encoded: string = base64.encodeToStringSync(bytes);
    this.authHeader = `Basic ${encoded}`;
  }

  /** 拼接完整 URL */
  private getFullUrl(path: string): string {
    const cleanPath: string = path.startsWith('/') ? path.substring(1) : path;
    return this.baseUrl + cleanPath;
  }

  /** 发送 HTTP 请求的通用方法 */
  private async sendRequest(
    method: http.RequestMethod | string,
    path: string,
    options?: SendRequestOptions
  ): Promise<http.HttpResponse> {
    const url: string = this.getFullUrl(path);
    const headers: Record<string, string> = {
      'Authorization': this.authHeader,
      'User-Agent': 'CardNote-WebDAV/1.0',
    };

    if (options?.contentType) {
      headers['Content-Type'] = options.contentType;
    }
    if (options?.extraHeaders) {
      const keys: string[] = Object.keys(options.extraHeaders);
      keys.forEach((key: string) => {
        headers[key] = options.extraHeaders![key];
      });
    }

    const requestOptions: http.HttpRequestOptions = {
      method: method as http.RequestMethod,
      header: headers,
      connectTimeout: 30000,
      readTimeout: 60000,
    };

    if (options?.body) {
      requestOptions.extraData = options.body;
    }

    const httpRequest: http.HttpRequest = http.createHttp();

    try {
      const response: http.HttpResponse = await httpRequest.request(url, requestOptions);
      return response;
    } finally {
      httpRequest.destroy();
    }
  }

  // ==========================================
  // 基础操作
  // ==========================================

  /** 下载文件内容为字符串 */
  async getText(remotePath: string): Promise<string> {
    const response: http.HttpResponse = await this.sendRequest(
      http.RequestMethod.GET,
      remotePath
    );
    if (response.responseCode !== 200) {
      throw new Error(`GET ${remotePath} failed: HTTP ${response.responseCode}`);
    }
    // 优先使用 resultType 判断，避免 typeof/instanceof 限制
    if (response.resultType === http.HttpDataType.STRING) {
      return response.result as string;
    }
    if (response.resultType === http.HttpDataType.ARRAY_BUFFER) {
      const decoder: util.TextDecoder = new util.TextDecoder('utf-8');
      return decoder.decodeToString(new Uint8Array(response.result as ArrayBuffer));
    }
    throw new Error('Unsupported response type from GET');
  }

  /** 上传文本内容 */
  async putText(remotePath: string, content: string, contentType: string = 'application/json'): Promise<void> {
    const opts: SendRequestOptions = new SendRequestOptions(content, contentType);
    const response: http.HttpResponse = await this.sendRequest(
      http.RequestMethod.PUT,
      remotePath,
      opts
    );
    if (response.responseCode !== 200 && response.responseCode !== 201 && response.responseCode !== 204) {
      throw new Error(`PUT ${remotePath} failed: HTTP ${response.responseCode}`);
    }
  }

  /** 删除文件 */
  async deleteFile(remotePath: string): Promise<void> {
    const response: http.HttpResponse = await this.sendRequest(
      http.RequestMethod.DELETE,
      remotePath
    );
    if (response.responseCode !== 200 && response.responseCode !== 204) {
      throw new Error(`DELETE ${remotePath} failed: HTTP ${response.responseCode}`);
    }
  }

  /** 创建目录（MKCOL） */
  async createDirectory(remotePath: string): Promise<void> {
    const response: http.HttpResponse = await this.sendRequest(
      'MKCOL',
      remotePath
    );
    if (response.responseCode !== 201 && response.responseCode !== 200) {
      throw new Error(`MKCOL ${remotePath} failed: HTTP ${response.responseCode}`);
    }
  }

  /** 检查文件是否存在 */
  async exists(remotePath: string): Promise<boolean> {
    try {
      const response: http.HttpResponse = await this.sendRequest(
        http.RequestMethod.HEAD,
        remotePath
      );
      return response.responseCode === 200;
    } catch (err) {
      return false;
    }
  }

  /** 列出目录内容（PROPFIND，仅返回一级子目录） */
  async listDirectory(remotePath: string = ''): Promise<WebDAVItem[]> {
    const body: string =
      '<?xml version="1.0" encoding="utf-8"?>\n' +
      '<D:propfind xmlns:D="DAV:">\n' +
      '  <D:prop>\n' +
      '    <D:displayname/>\n' +
      '    <D:resourcetype/>\n' +
      '    <D:getcontenttype/>\n' +
      '    <D:getcontentlength/>\n' +
      '    <D:getlastmodified/>\n' +
      '  </D:prop>\n' +
      '</D:propfind>';

    const opts: SendRequestOptions = new SendRequestOptions(
      body,
      'application/xml; charset=utf-8',
      { 'Depth': '1' }
    );

    const response: http.HttpResponse = await this.sendRequest(
      'PROPFIND',
      remotePath,
      opts
    );

    if (response.responseCode !== 207) {
      throw new Error(`PROPFIND ${remotePath} failed: HTTP ${response.responseCode}`);
    }

    const text: string = this.responseToString(response);
    return this.parsePropfindResponse(text, remotePath);
  }

  /** 将响应体转为字符串 */
  private responseToString(response: http.HttpResponse): string {
    if (response.resultType === http.HttpDataType.STRING) {
      return response.result as string;
    }
    if (response.resultType === http.HttpDataType.ARRAY_BUFFER) {
      const decoder: util.TextDecoder = new util.TextDecoder('utf-8');
      return decoder.decodeToString(new Uint8Array(response.result as ArrayBuffer));
    }
    return '';
  }

  /** 简单解析 PROPFIND multistatus XML */
  private parsePropfindResponse(xml: string, requestPath: string): WebDAVItem[] {
    const items: WebDAVItem[] = [];
    // 用正则提取每个 <D:response>...</D:response>
    const responseRegex: RegExp = /<D:response>([\s\S]*?)<\/D:response>/gi;
    let match: RegExpExecArray | null;
    let first: boolean = true;

    while ((match = responseRegex.exec(xml)) !== null) {
      const block: string = match[1];
      // 提取 href
      const hrefMatch: RegExpMatchArray | null = block.match(/<D:href>(.*?)<\/D:href>/i);
      if (!hrefMatch) {
        continue;
      }
      let href: string = hrefMatch[1];
      // 去掉请求路径前缀，得到相对名
      const name: string = href.replace(/\/$/, '').split('/').pop() || href;

      // 跳过自身（第一个 response 通常是请求路径自身）
      if (first) {
        first = false;
        continue;
      }
      if (!name || name === '') {
        continue;
      }

      const isDir: boolean = /<D:collection\/>/i.test(block) || /<D:collection><\/D:collection>/i.test(block);

      // 提取 displayname
      let displayName: string = name;
      const dnMatch: RegExpMatchArray | null = block.match(/<D:displayname>(.*?)<\/D:displayname>/i);
      if (dnMatch && dnMatch[1].trim() !== '') {
        displayName = dnMatch[1];
      }

      // content type
      let contentType: string = '';
      const ctMatch: RegExpMatchArray | null = block.match(/<D:getcontenttype>(.*?)<\/D:getcontenttype>/i);
      if (ctMatch) {
        contentType = ctMatch[1];
      }

      // size
      let size: number = 0;
      const sizeMatch: RegExpMatchArray | null = block.match(/<D:getcontentlength>(.*?)<\/D:getcontentlength>/i);
      if (sizeMatch) {
        size = parseInt(sizeMatch[1]) || 0;
      }

      // lastModified
      let lastModified: string = '';
      const lmMatch: RegExpMatchArray | null = block.match(/<D:getlastmodified>(.*?)<\/D:getlastmodified>/i);
      if (lmMatch) {
        lastModified = lmMatch[1];
      }

      items.push({
        name: name,
        path: href,
        isDirectory: isDir,
        size: size,
        lastModified: lastModified,
        contentType: contentType,
      });
    }

    return items;
  }
}
