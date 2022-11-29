/// low-level access to the OperatingSystem Sockets API (e.g. WinSock2)
// - this unit is a part of the Open Source Synopse mORMot framework 2,
// licensed under a MPL/GPL/LGPL three license - see LICENSE.md
unit mormot.net.sock;

{
  *****************************************************************************

   Cross-Platform Raw Sockets API Definition
   - Socket Process High-Level Encapsulation
   - MAC and IP Addresses Support
   - TLS / HTTPS Encryption Abstract Layer
   - Efficient Multiple Sockets Polling
   - TUri parsing/generating URL wrapper
   - TCrtSocket Buffered Socket Read/Write Class

   The Low-Level Sockets API, which is complex and inconsistent among OS, is
   not made public and shouldn't be used in end-user code. This unit
   encapsultates all Sockets features into a single set of functions, and
   around the TNetSocket abstract wrapper.

  *****************************************************************************

  Notes:
    Oldest Delphis didn't include WinSock2.pas, so we defined our own.
    Under POSIX, will redirect to the libc or regular FPC units.

}


interface

{$I ..\mormot.defines.inc}


uses
  sysutils,
  classes,
  mormot.core.base,
  mormot.core.os;


{ ******************** Socket Process High-Level Encapsulation }

const
  cLocalhost = '127.0.0.1';
  cAnyHost = '0.0.0.0';
  cBroadcast = '255.255.255.255';
  c6Localhost = '::1';
  c6AnyHost = '::';
  c6Broadcast = 'ffff::1';
  cAnyPort = '0';
  cLocalhost32 = $0100007f;

  {$ifdef OSWINDOWS}
  SOCKADDR_SIZE = 28;
  {$else}
  SOCKADDR_SIZE = 110; // able to store UNIX domain socket name
  {$endif OSWINDOWS}

var
  /// global variable containing '127.0.0.1'
  // - defined as var not as const to use reference counting from TNetAddr.IP
  IP4local: RawUtf8;

type
  /// the error codes returned by TNetSocket wrapper
  // - convenient cross-platform error handling is not possible, mostly because
  // Windows doesn't behave exactly like other targets: this enumeration
  // flattens socket execution results, and allow easy ToText() text conversion
  TNetResult = (
    nrOK,
    nrRetry,
    nrNoSocket,
    nrNotFound,
    nrNotImplemented,
    nrClosed,
    nrFatalError,
    nrUnknownError,
    nrTooManyConnections,
    nrRefused,
    nrConnectTimeout);

  /// exception class raised by this unit
  ENetSock = class(ExceptionWithProps)
  protected
    fLastError: TNetResult;
  public
    /// reintroduced constructor with TNetResult information
    constructor Create(msg: string; const args: array of const;
      error: TNetResult = nrOK); reintroduce;
    /// raise ENetSock if res is not nrOK or nrRetry
    class procedure Check(res: TNetResult; const Context: ShortString);
    /// call NetLastError and raise ENetSock if not nrOK nor nrRetry
    class procedure CheckLastError(const Context: ShortString;
      ForceRaise: boolean = false; AnotherNonFatal: integer = 0);
  published
    property LastError: TNetResult
      read fLastError default nrOk;
  end;

  /// one data state to be tracked on a given socket
  TNetEvent = (
    neRead,
    neWrite,
    neError,
    neClosed);

  /// the current whole read/write state on a given socket
  TNetEvents = set of TNetEvent;

  /// the available socket protocol layers
  // - by definition, nlUnix will return nrNotImplemented on Windows
  TNetLayer = (
    nlTcp,
    nlUdp,
    nlUnix);

  /// the available socket families - mapping AF_INET/AF_INET6/AF_UNIX
  TNetFamily = (
    nfUnknown,
    nfIP4,
    nfIP6,
    nfUnix);

  /// the IP port to connect/bind to
  TNetPort = cardinal;


const
  NO_ERROR = 0;

  /// the socket protocol layers over the IP protocol
  nlIP = [nlTcp, nlUdp];

type
  /// end-user code should use this TNetSocket type to hold a socket reference
  // - then methods allow cross-platform access to the connection
  TNetSocket = ^TNetSocketWrap;

  /// internal mapping of an address, in any supported socket layer
  TNetAddr = object
  private
    // opaque wrapper with len: sockaddr_un=110 (POSIX) or sockaddr_in6=28 (Win)
    Addr: array[0..SOCKADDR_SIZE - 1] of byte;
  public
    function SetFrom(const address, addrport: RawUtf8; layer: TNetLayer): TNetResult;
    function Family: TNetFamily;
    procedure IP(var res: RawUtf8; localasvoid: boolean = false); overload;
    function IP(localasvoid: boolean = false): RawUtf8; overload;
      {$ifdef HASINLINE}inline;{$endif}
    function IP4: cardinal;
      {$ifdef FPC}inline;{$endif}
    function IPShort(withport: boolean = false): ShortString; overload;
      {$ifdef HASINLINE}inline;{$endif}
    procedure IPShort(out result: ShortString; withport: boolean = false); overload;
    function IPWithPort: RawUtf8;
    function Port: TNetPort;
    function SetPort(p: TNetPort): TNetResult;
    function Size: integer;
      {$ifdef FPC}inline;{$endif}
    function IsEqualAfter64(const another: TNetAddr): boolean;
      {$ifdef FPC}inline;{$endif}
    function IsEqual(const another: TNetAddr): boolean;
    function NewSocket(layer: TNetLayer): TNetSocket;
  end;

  /// pointer to a socket address mapping
  PNetAddr = ^TNetAddr;

  TNetAddrDynArray = array of TNetAddr;

  TNetSocketDynArray = array of TNetSocket;
  PNetSocketDynArray = ^TNetSocketDynArray;

  PTerminated = ^boolean; // on FPC system.PBoolean doesn't exist :(

  /// convenient object-oriented wrapper around a socket connection
  // - encapsulate a cross-platform low-level access to the socket API
  // - TNetSocket is a pointer to this, so TSocket(@self) is used for OS calls
  TNetSocketWrap = object
  private
    procedure SetOpt(prot, name: integer; value: pointer; valuelen: integer);
    function GetOptInt(prot, name: integer): integer;
    function SetIoMode(async: cardinal): TNetResult;
    procedure SetSendBufferSize(bytes: integer);
    procedure SetRecvBufferSize(bytes: integer);
    function GetSendBufferSize: integer;
    function GetRecvBufferSize: integer;
  public
    procedure SetupConnection(layer: TNetLayer; sendtimeout, recvtimeout: integer);
    procedure SetSendTimeout(ms: integer);
    procedure SetReceiveTimeout(ms: integer);
    procedure SetKeepAlive(keepalive: boolean);
    procedure SetLinger(linger: integer);
    procedure SetNoDelay(nodelay: boolean);
    function Accept(out clientsocket: TNetSocket; out addr: TNetAddr;
      async: boolean): TNetResult;
    function GetPeer(out addr: TNetAddr): TNetResult;
    function MakeAsync: TNetResult;
    function MakeBlocking: TNetResult;
    function Send(Buf: pointer; var len: integer): TNetResult;
    function Recv(Buf: pointer; var len: integer): TNetResult;
    function SendTo(Buf: pointer; len: integer; const addr: TNetAddr): TNetResult;
    function RecvFrom(Buf: pointer; len: integer; out addr: TNetAddr): integer;
    function WaitFor(ms: integer; scope: TNetEvents; loerr: system.PInteger = nil): TNetEvents;
    function RecvPending(out pending: integer): TNetResult;
    function RecvWait(ms: integer; out data: RawByteString;
      terminated: PTerminated = nil): TNetResult;
    function SendAll(Buf: PByte; len: integer;
      terminated: PTerminated = nil): TNetResult;
    function ShutdownAndClose(rdwr: boolean): TNetResult;
    function Close: TNetResult;
    function Socket: PtrInt;
      {$ifdef HASINLINE}inline;{$endif}
    property SendBufferSize: integer
      read GetSendBufferSize write SetSendBufferSize;
    property RecvBufferSize: integer
      read GetRecvBufferSize write SetRecvBufferSize;
  end;


  /// used by NewSocket() to cache the host names via NewSocketAddressCache global
  // - defined in this unit, but implemented in mormot.net.client.pas
  // - the implementation should be thread-safe
  INewSocketAddressCache = interface
    /// method called by NewSocket() to resolve its address
    function Search(const Host: RawUtf8; out NetAddr: TNetAddr): boolean;
    /// once resolved, NewSocket() will call this method to cache the TNetAddr
    procedure Add(const Host: RawUtf8; const NetAddr: TNetAddr);
    /// called by NewSocket() if connection failed, and force DNS resolution
    procedure Flush(const Host: RawUtf8);
    /// you can call this method to change the default timeout of 10 minutes
    procedure SetTimeOut(aSeconds: integer);
  end;

/// internal low-level function retrieving the latest socket error information
function NetLastError(AnotherNonFatal: integer = NO_ERROR;
  Error: system.PInteger = nil): TNetResult;

/// internal low-level function retrieving the latest socket error message
function NetLastErrorMsg(AnotherNonFatal: integer = NO_ERROR): ShortString;

/// create a new Socket connected or bound to a given ip:port
function NewSocket(const address, port: RawUtf8; layer: TNetLayer;
  dobind: boolean; connecttimeout, sendtimeout, recvtimeout, retry: integer;
  out netsocket: TNetSocket; netaddr: PNetAddr = nil): TNetResult;

/// resolve the TNetAddr of the address:port layer - maybe from cache
function GetSocketAddressFromCache(const address, port: RawUtf8;
  layer: TNetLayer; out addr: TNetAddr; var fromcache, tobecached: boolean): TNetResult;

/// try to connect to several address:port servers simultaneously
// - return up to neededcount connected TNetAddr, until timeoutms expires
// - sockets are closed unless sockets^[] should contain the result[] sockets
function GetReachableNetAddr(const address, port: array of RawUtf8;
  timeoutms: integer = 1000; neededcount: integer = 1;
  sockets: PNetSocketDynArray = nil): TNetAddrDynArray;

var
  /// contains the raw Socket API version, as returned by the Operating System
  SocketApiVersion: RawUtf8;

  /// used by NewSocket() to cache the host names
  // - avoiding DNS resolution is a always a good idea
  // - implemented by mormot.net.client unit using a TSynDictionary
  // - you may call its SetTimeOut or Flush methods to tune the caching
  NewSocketAddressCache: INewSocketAddressCache;

  /// Queue length for completely established sockets waiting to be accepted,
  // a backlog parameter for listen() function. If queue overflows client count,
  // ECONNREFUSED error is returned from connect() call
  // - for Windows default $7fffffff should not be modified. Actual limit is 200
  // - for Unix default is taken from constant (128 as in linux kernel >2.2),
  // but actual value is min(DefaultListenBacklog, /proc/sys/net/core/somaxconn)
  DefaultListenBacklog: integer;

  /// defines if a connection from the loopback should be reported as ''
  // - loopback connection will have no Remote-IP - for the default true
  // - or loopback connection will be explicitly '127.0.0.1' - if equals false
  // - used by both TCrtSock.AcceptRequest and THttpApiServer.Execute servers
  RemoteIPLocalHostAsVoidInServers: boolean = true;


/// returns the plain English text of a network result
// - e.g. ToText(nrNotFound)='Not Found'
function ToText(res: TNetResult): PShortString; overload;


{ ******************** Mac and IP Addresses Support }

type
  TIPAddress = (
    tiaAny,
    tiaIPv4,
    tiaIPv4Public,
    tiaIPv4Private,
    tiaIPv6);

/// detect IANA private IPv4 address space from its 32-bit raw value
function IsPublicIP(ip4: cardinal): boolean;

/// convert an IPv4 raw value into a ShortString text
// - won't use the Operating System network layer API so works on XP too
// - zero is returned as '0.0.0.0' and loopback as '127.0.0.1'
procedure IP4Short(ip4addr: PByteArray; var s: ShortString);

/// convert an IPv4 raw value into a RawUtf8 text
// - zero '0.0.0.0' address  (i.e. bound to any host) is returned as ''
procedure IP4Text(ip4addr: PByteArray; var result: RawUtf8);

/// convert an IPv6 raw value into a ShortString text
// - will shorten the address using the regular 0 removal scheme, e.g.
// 2001:00b8:0a0b:12f0:0000:0000:0000:0001 returns '2001:b8:a0b:12f0::1'
// - zero is returned as '::' and loopback as '::1'
// - does not support mapped IPv4 so never returns '::1.2.3.4' but '::102:304'
// - won't use the Operating System network layer API so is fast and consistent
procedure IP6Short(ip6addr: PByteArray; var s: ShortString);

/// convert an IPv6 raw value into a RawUtf8 text
// - zero '::' address  (i.e. bound to any host) is returned as ''
// - loopback address is returned as its '127.0.0.1' IPv4 representation
// for consistency with our high-level HTTP/REST code
// - does not support mapped IPv4 so never returns '::1.2.3.4' but '::102:304'
procedure IP6Text(ip6addr: PByteArray; var result: RawUtf8);

/// convert a MAC address value into its standard RawUtf8 text representation
// - returns e.g. '12:50:b6:1e:c6:aa'
// - could be used to convert some binary buffer into human-friendly hexadecimal
// string, e.g. by asn1_string_st.ToHex() in our mormot.lib.openssl11 wrapper
function MacToText(mac: PByteArray; maclen: PtrInt = 6): RawUtf8;

/// convert a MAC address value from its standard hexadecimal text representation
// - returns e.g. '12:50:b6:1e:c6:aa' from '1250b61ec6aa' or '1250B61EC6AA'
function MacTextFromHex(const Hex: RawUtf8): RawUtf8;

/// convert a MAC address value into a RawUtf8 hexadecimal text with no ':'
// - returns e.g. '1250b61ec6aa'
function MacToHex(mac: PByteArray; maclen: PtrInt = 6): RawUtf8;

/// enumerate all IP addresses of the current computer
// - may be used to enumerate all adapters
function GetIPAddresses(Kind: TIPAddress = tiaIPv4): TRawUtf8DynArray;

/// returns all IP addresses of the current computer as a single CSV text
// - may be used to enumerate all adapters
function GetIPAddressesText(const Sep: RawUtf8 = ' ';
  Kind: TIPAddress = tiaIPv4): RawUtf8;

/// flush the GetIPAddresses/GetMacAddresses internal cache
// - may be set to force detection after HW configuration change
procedure MacIPAddressFlush;


type
  /// interface name/address pairs as returned by GetMacAddresses
  TMacAddress = record
    /// contains e.g. 'eth0' on Linux
    Name: RawUtf8;
    /// contains e.g. '12:50:b6:1e:c6:aa' from /sys/class/net/eth0/adddress
    Address: RawUtf8;
  end;
  TMacAddressDynArray = array of TMacAddress;

/// enumerate all Mac addresses of the current computer
function GetMacAddresses(UpAndDown: boolean = false): TMacAddressDynArray;

/// enumerate all Mac addresses of the current computer as 'name1=addr1 name2=addr2'
function GetMacAddressesText(WithoutName: boolean = true;
  UpAndDown: boolean = false): RawUtf8;


{$ifdef OSWINDOWS}
/// remotly get the MAC address of a computer, from its IP Address
// - only works under Win2K and later, which features a ARP protocol client
// - return the MAC address as a 12 hexa chars ('0050C204C80A' e.g.)
function GetRemoteMacAddress(const IP: RawUtf8): RawUtf8;
{$endif OSWINDOWS}


{ ******************** TLS / HTTPS Encryption Abstract Layer }

type
  /// pointer to TLS Options and Information for a given TCrtSocket connection
  PNetTlsContext = ^TNetTlsContext;

  /// callback raised by INetTls.AfterConnection to return a private key
  // password - typically prompting the user for it
  // - TLS is an opaque structure, typically an OpenSSL PSSL_CTX pointer
  TOnNetTlsGetPassword = function(Socket: TNetSocket;
    Context: PNetTlsContext; TLS: pointer): RawUtf8 of object;

  /// callback raised by INetTls.AfterConnection to validate a peer
  // - at this point, Context.CipherName is set, but PeerInfo, PeerIssuer and
  // PeerSubject are not - it is up to the event to compute the PeerInfo value
  // - TLS is an opaque structure, typically an OpenSSL PSSL pointer, so you
  // could use e.g. PSSL(TLS).PeerCertificates array
  TOnNetTlsPeerValidate = procedure(Socket: TNetSocket;
    Context: PNetTlsContext; TLS: pointer) of object;

  /// callback raised by INetTls.AfterConnection after validating a peer
  // - called after standard peer validation - ignored by TOnNetTlsPeerValidate
  // - Context.CipherName, LastError PeerIssuer and PeerSubject are set
  // - TLS and Peer are opaque structures, typically OpenSSL PSSL and PX509
  TOnNetTlsAfterPeerValidate = procedure(Socket: TNetSocket;
    Context: PNetTlsContext; TLS, Peer: pointer) of object;

  /// callback raised by INetTls.AfterConnection for each peer verification
  // - wasok=true if the TLS library did validate the incoming certificate
  // - should process the supplied peer information, and return true to continue
  // and accept the connection, or false to abort the connection
  // - Context.PeerIssuer and PeerSubject have been properly populated from Peer
  // - TLS and Peer are opaque structures, typically OpenSSL PSSL and PX509 pointers
  TOnNetTlsEachPeerVerify = function(Socket: TNetSocket; Context: PNetTlsContext;
    wasok: boolean; TLS, Peer: pointer): boolean of object;

  /// callback raised by INetTls.AfterAccept for SNI resolution
  // - should check the ServerName and return the proper certificate context,
  // typically one OpenSSL PSSL_CTX instance
  // - if the ServerName has no match, and the default certificate is good
  // enough, should return nil
  // - on any error, should raise an exception
  // - TLS is an opaque structure, typically OpenSSL PSSL
  TOnNetTlsAcceptServerName = function(Context: PNetTlsContext; TLS: pointer;
    const ServerName: RawUtf8): pointer of object;

  /// TLS Options and Information for a given TCrtSocket/INetTls connection
  // - currently only properly implemented by mormot.lib.openssl11 - SChannel
  // on Windows only recognizes IgnoreCertificateErrors and sets CipherName
  // - typical usage is the following:
  // $ with THttpClientSocket.Create do
  // $ try
  // $   TLS.WithPeerInfo := true;
  // $   TLS.IgnoreCertificateErrors := true;
  // $   TLS.CipherList := 'ECDHE-RSA-AES256-GCM-SHA384';
  // $   OpenBind('synopse.info', '443', {bind=}false, {tls=}true);
  // $   writeln(TLS.PeerInfo);
  // $   writeln(TLS.CipherName);
  // $   writeln(Get('/forum/', 1000), ' len=', ContentLength);
  // $   writeln(Get('/fossil/wiki/Synopse+OpenSource', 1000));
  // $ finally
  // $   Free;
  // $ end;
  // - for passing a PNetTlsContext, use InitNetTlsContext for initialization
  TNetTlsContext = record
    /// output: set by TCrtSocket.OpenBind() method once TLS is established
    Enabled: boolean;
    /// input: let HTTPS be less paranoid about TLS certificates
    // - on client: will avoid checking the server certificate, so will
    // allow to connect and encrypt e.g. with secTLSSelfSigned servers
    // - on OpenSSL server, should be true if no mutual authentication is done,
    // i.e. if OnPeerValidate/OnEachPeerVerify callbacks are not set
    IgnoreCertificateErrors: boolean;
    /// input: if PeerInfo field should be retrieved once connected
    // - ignored on SChannel
    WithPeerInfo: boolean;
    /// input: if deprecated TLS 1.0 or TLS 1.1 are allowed
    // - default is TLS 1.2+ only, and deprecated SSL 2/3 are always disabled
    AllowDeprecatedTls: boolean;
    /// input: PEM/PFX file name containing a certificate to be loaded
    // - (Delphi) warning: encoded as UTF-8 not UnicodeString/TFileName
    // - on OpenSSL client or server, calls SSL_CTX_use_certificate_file() API
    // - not used on SChannel client
    // - on SChannel server, expects a .pfx / PKCS#12 file format including
    // the certificate and the private key, e.g. generated from
    // ICryptCert.SaveToFile(FileName, cccCertWithPrivateKey, ', ccfBinary) or
    // openssl pkcs12 -inkey privkey.pem -in cert.pem -export -out mycert.pfx
    CertificateFile: RawUtf8;
    /// input: PEM file name containing a private key to be loaded
    // - (Delphi) warning: encoded as UTF-8 not UnicodeString/TFileName
    // - on OpenSSL client or server, calls SSL_CTX_use_PrivateKey_file() API
    // - not used on SChannel
    PrivateKeyFile: RawUtf8;
    /// input: optional password to load the PrivateKey file
    // - see also OnPrivatePassword callback
    // - on OpenSSL client or server, calls SSL_CTX_set_default_passwd_cb_userdata() API
    // - not used on SChannel
    PrivatePassword: RawUtf8;
    /// input: file containing a specific set of CA certificates chain
    // - e.g. entrust_2048_ca.cer from https://web.entrust.com
    // - (Delphi) warning: encoded as UTF-8 not UnicodeString/TFileName
    // - on OpenSSL, calls the SSL_CTX_load_verify_locations() API
    // - not used on SChannel
    CACertificatesFile: RawUtf8;
    /// input: preferred Cipher List
    // - not used on SChannel
    CipherList: RawUtf8;
    /// input: a CSV list of host names to be validated
    // - e.g. 'smtp.example.com,example.com'
    // - not used on SChannel
    HostNamesCsv: RawUtf8;
    /// output: the cipher description, as used for the current connection
    // - text format depends on the used TLS library e.g. on OpenSSL may be e.g.
    // 'ECDHE-RSA-AES128-GCM-SHA256 TLSv1.2 Kx=ECDH Au=RSA Enc=AESGCM(128) Mac=AEAD'
    // or 'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256_P256 TLSv1.2' with SChannel
    // (or less complete 'ECDHE256-AES128-SHA256 TLSv1.2' information on XP)
    CipherName: RawUtf8;
    /// output: the connected Peer issuer name
    // - e.g. '/C=US/O=Let''s Encrypt/CN=R3'
    // - not populated on SChannel, always on OpenSSL
    PeerIssuer: RawUtf8;
    /// output: the connected Peer subject name
    // - e.g. 'CN=synopse.info'
    // - not populated on SChannel, always on OpenSSL
    PeerSubject: RawUtf8;
    /// output: detailed information about the connected Peer
    // - stored in the native format of the TLS library, e.g. X509_print()
    // - only populated if WithPeerInfo was set to true, or an error occurred
    PeerInfo: RawUtf8;
    /// output: low-level details about the last error at TLS level
    // - typically one X509_V_ERR_* integer constant
    LastError: RawUtf8;
    /// called by INetTls.AfterConnection to fully customize peer validation
    // - not used on SChannel
    OnPeerValidate: TOnNetTlsPeerValidate;
    /// called by INetTls.AfterConnection for each peer validation
    // - allow e.g. to verify CN or DNSName fields of each peer certificate
    // - not used on SChannel
    OnEachPeerVerify: TOnNetTlsEachPeerVerify;
    /// called by INetTls.AfterConnection after standard peer validation
    // - allow e.g. to verify CN or DNSName fields of the peer certificate
    // - not used on SChannel
    OnAfterPeerValidate: TOnNetTlsAfterPeerValidate;
    /// called by INetTls.AfterConnection to retrieve a private password
    // - not used on SChannel
    OnPrivatePassword: TOnNetTlsGetPassword;
    /// called by INetTls.AfterAccept to set a server/host-specific certificate
    // - not used on SChannel
    OnAcceptServerName: TOnNetTlsAcceptServerName;
    /// opaque pointer used by INetTls.AfterBind/AfterAccept to propagate the
    // bound server certificate context into each accepted connection
    // - so that certificates are decoded only once in AfterBind
    // - is typically a PSSL_CTX on OpenSSL
    AcceptCert: pointer;
  end;

  /// abstract definition of the TLS encrypted layer
  // - is implemented e.g. by the SChannel API on Windows, or OpenSSL on POSIX
  // if you include mormot.lib.openssl11 to your project
  INetTls = interface
    /// method called once to attach the socket from the client side
    // - should make the proper client-side TLS handshake and create a session
    // - should raise an exception on error
    procedure AfterConnection(Socket: TNetSocket; var Context: TNetTlsContext;
      const ServerAddress: RawUtf8);
    /// method called once the socket has been bound on server side
    // - will set Context.AcceptCert with reusable server certificates info
    procedure AfterBind(var Context: TNetTlsContext);
    /// method called for each new connection accepted on server side
    // - should make the proper server-side TLS handshake and create a session
    // - should raise an exception on error
    // - BoundContext is the associated server instance with proper AcceptCert
    // as filled by AfterBind()
    procedure AfterAccept(Socket: TNetSocket; const BoundContext: TNetTlsContext;
      LastError, CipherName: PRawUtf8);
    /// retrieve the textual name of the cipher used following AfterAccept()
    function GetCipherName: RawUtf8;
    /// return the low-level TLS instance used, depending on the engine
    // - typically a PSSL on OpenSSL, so you can use e.g. PSSL().PeerCertificate,
    // or a PCtxtHandle on SChannel
    function GetRawTls: pointer;
    /// receive some data from the TLS layer
    function Receive(Buffer: pointer; var Length: integer): TNetResult;
    /// send some data from the TLS layer
    function Send(Buffer: pointer; var Length: integer): TNetResult;
  end;

  /// signature of a factory for a new TLS encrypted layer
  TOnNewNetTls = function: INetTls;

  /// event called by HTTPS server to publish HTTP-01 challenges on port 80
  // - Let's Encrypt typical uri is '/.well-known/acme-challenge/<TOKEN>'
  // - the server should send back the returned content as response with
  // application/octet-stream (i.e. BINARY_CONTENT_TYPE)
  TOnNetTlsAcceptChallenge = function(const domain, uri: RawUtf8;
    var content: RawUtf8): boolean;


/// initialize a stack-allocated TNetTlsContext instance
procedure InitNetTlsContext(var TLS: TNetTlsContext; Server: boolean = false;
  const CertificateFile: TFileName = ''; const PrivateKeyFile: TFileName = '';
  const PrivateKeyPassword: RawUtf8 = ''; const CACertificatesFile: TFileName = '');

var
  /// global factory for a new TLS encrypted layer for TCrtSocket
  // - on Windows, this unit will set a factory using the system SChannel API
  // - on other targets, could be set by the mormot.lib.openssl11.pas unit
  NewNetTls: TOnNewNetTls;

  /// global callback set to TNetTlsContext.AfterAccept from InitNetTlsContext()
  // - defined e.g. by mormot.net.acme.pas unit to support Let's Encrypt
  // - any HTTPS server should also publish a HTTP server on port 80 to serve
  // HTTP-01 challenges via the OnNetTlsAcceptChallenge callback
  OnNetTlsAcceptServerName: TOnNetTlsAcceptServerName;

  /// global callback used for HTTP-01 Let's Encrypt challenges
  // - defined e.g. by mormot.net.acme.pas unit to support Let's Encrypt
  // - any HTTPS server should also publish a HTTP server on port 80 to serve
  // HTTP-01 challenges associated with the OnNetTlsAcceptServerName callback
  OnNetTlsAcceptChallenge: TOnNetTlsAcceptChallenge;


{ ******************** Efficient Multiple Sockets Polling }

type
  /// the events monitored by TPollSocketAbstract
  // - we don't make any difference between urgent or normal read/write events
  TPollSocketEvent = (
    pseRead,
    pseWrite,
    pseError,
    pseClosed);

  /// set of events monitored by TPollSocketAbstract
  TPollSocketEvents = set of TPollSocketEvent;

  /// some opaque value (typically a pointer) associated with a polling event
  TPollSocketTag = type PtrInt;
  PPollSocketTag = ^TPollSocketTag;
  TPollSocketTagDynArray = TPtrUIntDynArray;

  /// modifications notified by TPollSocketAbstract.WaitForModified
  {$ifdef CPUINTEL}
  TPollSocketResult =  packed record
  {$else}
  TPollSocketResult =  record // ARM uslaly prefers aligned data
  {$endif CPUINTEL}
    /// opaque value as defined by TPollSocketAbstract.Subscribe
    // - holds typically a TPollAsyncConnection instance
    tag: TPollSocketTag;
    /// the events which are notified
    events: TPollSocketEvents;
  end;
  PPollSocketResult = ^TPollSocketResult;
  TPollSocketResultDynArray = array of TPollSocketResult;

  /// all modifications returned by TPollSocketAbstract.WaitForModified
  TPollSocketResults = record
    // hold [0..Count-1] notified events
    Events: TPollSocketResultDynArray;
    /// how many modifications are currently monitored in Results[]
    Count: PtrInt;
  end;

  {$M+}
  TPollSockets = class;

  /// abstract parent for TPollSocket* and TPollSockets polling
  TPollAbstract = class
  protected
    fCount: integer;
  public
    /// track status modifications on one specified TSocket
    // - you can specify which events are monitored - pseError and pseClosed
    // will always be notified
    // - tag parameter will be returned as TPollSocketResult - you may set
    // here the socket file descriptor value, or a transtyped class instance
    // - similar to epoll's EPOLL_CTL_ADD control interface
    function Subscribe(socket: TNetSocket; events: TPollSocketEvents;
      tag: TPollSocketTag): boolean; virtual; abstract;
    /// should finalize this processing before shutdown
    procedure Terminate; virtual;
  published
    /// how many TSocket instances are currently tracked
    property Count: integer
      read fCount;
  end;
  {$M-}

  /// abstract parent class for efficient socket polling
  // - on Linux, FollowEpoll=true uses the epoll API in level-triggered (LT) mode
  // - on other systems (Windows or BSD), fallback to select or poll API, with
  // FollowEpoll=false - note that Subscribe/Unsubscribe should be delayed
  // outside the WaitForModified() call using an async separated list
  // - implements libevent-like cross-platform features
  // - use PollSocketClass global function to retrieve the best class depending
  // on the running Operating System
  // - actual classes are hidden in the implementation section of this unit,
  // and will use the fastest available API on each Operating System
  TPollSocketAbstract = class(TPollAbstract)
  protected
    fMaxSockets: integer;
    fOwner: TPollSockets;
  public
    /// initialize the polling
    constructor Create(aOwner: TPollSockets); virtual;
    /// stop status modifications tracking on one specified TSocket
    // - the socket should have been monitored by a previous call to Subscribe()
    // - on success, returns true and fill tag with the associated opaque value
    // - similar to epoll's EPOLL_CTL_DEL control interface
    function Unsubscribe(socket: TNetSocket): boolean; virtual; abstract;
    /// waits for status modifications of all tracked TSocket
    // - will wait up to timeoutMS milliseconds, 0 meaning immediate return
    // and -1 for infinite blocking
    // - returns false on error (e.g. no TSocket registered) or no event
    // - returns true and results.Events[0..results.Count-1] notifications
    function WaitForModified(var results: TPollSocketResults;
      timeoutMS: integer): boolean; virtual; abstract;
    /// if this poll has no size limit, and subscription/wait is thread safe
    // with edge detection
    // - false for select/poll, but true for epoll
    // - follow POLLSOCKETEPOLL conditional within this unit
    class function FollowEpoll: boolean;
  published
    /// how many TSocket instances could be tracked, at most
    // - depends on the API used
    property MaxSockets: integer
      read fMaxSockets;
  end;

  /// meta-class of TPollSocketAbstract socket polling classes
  // - since TPollSocketAbstract.Create is declared as virtual, could be used
  // to specify the proper polling class to add
  // - see PollSocketClass function and TPollSocketAbstract.New method
  TPollSocketClass = class of TPollSocketAbstract;

  /// TPollSockets.OnGetOneIdle callback prototype
  TOnPollSocketsIdle = procedure(Sender: TObject; NowTix: Int64) of object;

  // as used by TPollSockets.Subscribe for select/poll thread safety
  TPollSocketsSubscribe = record
    socket: TNetSocket;
    tag: TPollSocketTag;
    events: TPollSocketEvents;
  end;
  PPollSocketsSubscribe = ^TPollSocketsSubscribe;

  // as used by TPollSockets.Subscribe/Unsubscribe for select/poll thread safety
  TPollSocketsSubscription = record
    Unsubscribe: TNetSocketDynArray;
    Subscribe: array of TPollSocketsSubscribe;
    UnsubscribeCount: integer;
    SubscribeCount: integer;
  end;

  /// implements efficient polling of multiple sockets
  // - will maintain a pool of TPollSocketAbstract instances, to monitor
  // incoming data or outgoing availability for a set of active connections
  // - call Subscribe/Unsubscribe to setup the monitored sockets
  // - call GetOne from a main thread, optionally GetOnePending from sub-threads
  TPollSockets = class(TPollAbstract)
  protected
    fPoll: array of TPollSocketAbstract; // each track up to fPoll[].MaxSockets
    fPending: TPollSocketResults;
    fPendingIndex: PtrInt;
    fPendingSafe: TLightLock;
    fPollIndex: integer;
    fGettingOne: integer;
    fTerminated: boolean;
    fEpollGettingOne: boolean;
    fUnsubscribeShouldShutdownSocket: boolean;
    fPollClass: TPollSocketClass;
    fOnLog: TSynLogProc;
    fOnGetOneIdle: TOnPollSocketsIdle;
    // used for select/poll (FollowEpoll=false) with multiple thread-unsafe fPoll[]
    fSubscription: TPollSocketsSubscription;
    fSubscriptionSafe: TLightLock; // dedicated not to block Accept()
    fPollLock: TRTLCriticalSection;
    function GetSubscribeCount: integer;
    function GetUnsubscribeCount: integer;
    function MergePendingEvents(const new: TPollSocketResults): integer;
    // virtual methods below could be overridden for O(1) pending state check
    function EnsurePending(tag: TPollSocketTag): boolean; virtual;
    procedure SetPending(tag: TPollSocketTag); virtual;
    function UnsetPending(tag: TPollSocketTag): boolean; virtual;
  public
    /// initialize the sockets polling
    // - under Linux/POSIX, will set the open files maximum number for the
    // current process to match the system hard limit: if your system has a
    // low "ulimit -H -n" value, you may add the following line in your
    // /etc/limits.conf or /etc/security/limits.conf file:
    // $ * hard nofile 65535
    constructor Create(aPollClass: TPollSocketClass = nil);
    /// finalize the sockets polling, and release all used memory
    destructor Destroy; override;
    /// track modifications on one specified TSocket and tag
    // - the supplied tag value - maybe a PtrInt(aObject) - will be part of
    // GetOne/GetOnePending methods TPollSocketResult.Tag results
    // - will create as many TPollSocketAbstract instances as needed, depending
    // on the MaxSockets capability of the actual implementation class
    // - this method is thread-safe, and the actual fPoll[].Subscribe
    // will take place during the next PollForPendingEvents() call
    function Subscribe(socket: TNetSocket; events: TPollSocketEvents;
      tag: TPollSocketTag): boolean; override;
    /// stop status modifications tracking on one specified TSocket and tag
    // - the socket should have been monitored by a previous call to Subscribe()
    // - this method is thread-safe, and the actual fPoll[].UnSubscribe
    // will take place during the next PollForPendingEvents() call
    procedure Unsubscribe(socket: TNetSocket; tag: TPollSocketTag); virtual;
    /// retrieve the next pending notification, or let the poll wait for new
    // - if GetOnePending returns no pending notification, will try
    // PollForPendingEvents and wait up to timeoutMS milliseconds for events
    // - returns true and set notif.events/tag with the corresponding notification
    // - returns false if no pending event was handled within the timeoutMS period
    // - warning: this method should be called from a single thread on Linux
    // (PollClass.FollowEpoll=true) since epoll_wait() is used - other select/poll
    // API would work on concurrent call, but with lost resources - typically, a
    // main thread calls GetOne() while other threads could call GetOnePending()
    function GetOne(timeoutMS: integer; const call: RawUtf8;
      out notif: TPollSocketResult): boolean; virtual;
    /// retrieve the next pending notification
    // - returns true and set notif.events/tag with the corresponding notification
    // - returns false if no pending event is available
    // - this method is thread-safe, and could be called from several threads
    function GetOnePending(out notif: TPollSocketResult; const call: RawUtf8): boolean;
    /// let the poll check for pending events and apend them to fPending results
    // - could be called when PendingCount=0, i.e. GetOnePending()=false
    // - returns how many new events have been retrieved for the subscribed sockets
    function PollForPendingEvents(timeoutMS: integer): integer; virtual;
    /// manually append one event to the pending nodifications
    // - ready to be retrieved by GetOnePending
    procedure AddOnePending(aTag: TPollSocketTag; aEvents: TPollSocketEvents;
      aSearchExisting: boolean);
    /// disable any pending notification associated with a given connection tag
    // - can be called when a connection is removed from the main logic
    // to ensure function UnsetPending() never raise any GPF, if the
    // connection has been set via AddOnePending() but not via Subscribe()
    function DeleteOnePending(aTag: TPollSocketTag): boolean;
    /// disable any pending notification associated with several connection tags
    // - note that aTag array will be sorted during the process
    function DeleteSeveralPending(aTag: PPollSocketTag; aTagCount: integer): integer;
    /// notify any GetOne waiting method to stop its polling loop
    procedure Terminate; override;
    /// indicates that Unsubscribe() should also call ShutdownAndClose(socket)
    // - Destroy will also shutdown any remaining sockets if PollForPendingEvents
    // has not been called before shutdown
    property UnsubscribeShouldShutdownSocket: boolean
      read fUnsubscribeShouldShutdownSocket write fUnsubscribeShouldShutdownSocket;
    /// the actual polling class used to track socket state changes
    property PollClass: TPollSocketClass
      read fPollClass write fPollClass;
    /// allow raw debugging via logs of the low-level process
    property OnLog: TSynLogProc
      read fOnLog write fOnLog;
    /// callback called by GetOne when Idle
    // - warning: any implementation should be very quick and non blocking
    property OnGetOneIdle: TOnPollSocketsIdle
      read fOnGetOneIdle write fOnGetOneIdle;
  published
    /// is set to true by the Terminate method
    property Terminated: boolean
      read fTerminated;
    /// the index of the last notified event in the internal queue
    property PendingIndex: PtrInt
      read fPendingIndex;
    /// how many notified events are currently in the internal queue
    property PendingCount: PtrInt
      read fPending.Count;
    /// how many connections are pending to be subscribed (poll/select API)
    property SubscribeCount: integer
      read GetSubscribeCount default 0;
    /// how many connections are pending to be unsubscribed (poll/select API)
    property UnsubscribeCount: integer
      read GetUnsubscribeCount default 0;
  end;


function ToText(ev: TPollSocketEvents): TShort8; overload;

/// class function factory, returning a socket polling class matching
// at best the current operating system
// - return a hidden TPollSocketSelect class under Windows, TPollSocketEpoll
// under Linux, or TPollSocketPoll on BSD
function PollSocketClass: TPollSocketClass;


{ *************************** TUri parsing/generating URL wrapper }

type
  /// structure used to parse an URI into its components
  // - ready to be supplied e.g. to a THttpRequest sub-class
  // - used e.g. by class function THttpRequest.Get()
  // - will decode standard HTTP/HTTPS urls or Unix sockets URI like
  // 'http://unix:/path/to/socket.sock:/url/path'
  {$ifdef USERECORDWITHMETHODS}
  TUri = record
  {$else}
  TUri = object
  {$endif USERECORDWITHMETHODS}
  public
    /// if the server is accessible via https:// and not plain http://
    Https: boolean;
    /// either nlTcp for HTTP/HTTPS or nlUnix for Unix socket URI
    Layer: TNetLayer;
    /// if the server is accessible via something else than http:// or https://
    // - e.g. 'ws' or 'wss' for ws:// or wss://
    Scheme: RawUtf8;
    /// the server name
    // - e.g. 'www.somewebsite.com' or 'path/to/socket.sock' Unix socket URI
    Server: RawUtf8;
    /// the server port
    // - e.g. '80'
    Port: RawUtf8;
    /// optional user for authentication, as retrieved before '@'
    // - e.g. from 'https://user:password@server:port/address'
    User: RawUtf8;
    /// optional password for authentication, as retrieved before '@'
    // - e.g. from 'https://user:password@server:port/address'
    Password: RawUtf8;
    /// the resource address, including optional parameters
    // - e.g. '/category/name/10?param=1'
    Address: RawUtf8;
    /// reset all stored information
    procedure Clear;
    /// fill the members from a supplied URI
    // - recognize e.g. 'http://Server:Port/Address', 'https://Server/Address',
    // 'Server/Address' (as http), or 'http://unix:/Server:/Address' (as nlUnix)
    // - recognize 'https://user:password@server:port/address' authentication
    // - returns TRUE is at least the Server has been extracted, FALSE on error
    function From(aUri: RawUtf8; const DefaultPort: RawUtf8 = ''): boolean;
    /// compute the whole normalized URI
    // - e.g. 'https://Server:Port/Address' or 'http://unix:/Server:/Address'
    function URI: RawUtf8;
    /// the server port, as integer value
    function PortInt: TNetPort;
    /// compute the root resource Address, without any URI-encoded parameter
    // - e.g. '/category/name/10'
    function Root: RawUtf8;
    /// returns BinToBase64(User + ':' + Password) encoded value
    function UserPasswordBase64: RawUtf8;
  end;
  PUri = ^TUri;


const
  /// the default TCP port as text, as DEFAULT_PORT[Https]
  DEFAULT_PORT: array[boolean] of RawUtf8 = (
    '80', '443');
  /// the default TCP port as integer, as DEFAULT_PORT_INT[Https]
  DEFAULT_PORT_INT: array[boolean] of TNetPort = (
    80, 443);

/// IdemPChar() like function, to avoid linking mormot.core.text
function NetStartWith(p, up: PUtf8Char): boolean;


{ ********* TCrtSocket Buffered Socket Read/Write Class }

type
  /// meta-class of a TCrtSocket (sub-)type
  TCrtSocketClass = class of TCrtSocket;

  /// identify the incoming data availability in TCrtSocket.SockReceivePending
  TCrtSocketPending = (
    cspSocketError,
    cspNoData,
    cspDataAvailable);

  TCrtSocketTlsAfter = (
    cstaConnect,
    cstaBind,
    cstaAccept);

  {$M+}
  /// Fast low-level Socket implementation
  // - direct access to the OS (Windows, Linux) network layer API
  // - use Open constructor to create a client to be connected to a server
  // - use Bind constructor to initialize a server
  // - use SockIn and SockOut (after CreateSock*) to read/readln or write/writeln
  //  as with standard Delphi text files (see SendEmail implementation)
  // - even if you do not use read(SockIn^), you may call CreateSockIn then
  // read the (binary) content via SockInRead/SockInPending methods, which would
  // benefit of the SockIn^ input buffer to maximize reading speed
  // - to write data, CreateSockOut and write(SockOut^) is not mandatory: you
  // rather may use SockSend() overloaded methods, followed by a SockFlush call
  // - in fact, you can decide whatever to use none, one or both SockIn/SockOut
  // - since this class rely on its internal optimized buffering system,
  // TCP_NODELAY is set to disable the Nagle algorithm
  // - our classes are (much) faster than the Indy or Synapse implementation
  TCrtSocket = class
  protected
    fSock: TNetSocket;
    fServer: RawUtf8;
    fPort: RawUtf8;
    fProxyUrl: RawUtf8;
    // set by AcceptRequest() from TVarSin
    fRemoteIP: RawUtf8;
    fSockIn: PTextFile;
    fSockOut: PTextFile;
    fTimeOut: PtrInt;
    fBytesIn: Int64;
    fBytesOut: Int64;
    fSecure: INetTls;
    fSockInEofError: integer;
    fWasBind: boolean;
    fSocketLayer: TNetLayer;
    // updated by every SockSend() call
    fSndBuf: RawByteString;
    fSndBufLen: integer;
    // updated during UDP connection, accessed via PeerAddress/PeerPort
    fPeerAddr: PNetAddr;
    procedure SetKeepAlive(aKeepAlive: boolean); virtual;
    procedure SetLinger(aLinger: integer); virtual;
    procedure SetReceiveTimeout(aReceiveTimeout: integer); virtual;
    procedure SetSendTimeout(aSendTimeout: integer); virtual;
    procedure SetTcpNoDelay(aTcpNoDelay: boolean); virtual;
    function GetRawSocket: PtrInt;
      {$ifdef HASINLINE}inline;{$endif}
  public
    /// direct access to the optional low-level HTTP proxy tunnelling information
    // - could have been assigned by a Tunnel.From() call
    // - User/Password would be taken into consideration for authentication
    Tunnel: TUri;
    /// direct access to the optional low-level TLS Options and Information
    // - depending on the actual INetTls implementation, some fields may not
    // be used nor populated - currently only supported by mormot.lib.openssl11
    TLS: TNetTlsContext;
    /// can be assigned to TSynLog.DoLog class method for low-level logging
    OnLog: TSynLogProc;
    /// common initialization of all constructors
    // - do not call directly, but use Open / Bind constructors instead
    constructor Create(aTimeOut: PtrInt = 10000); reintroduce; virtual;
    /// constructor to connect to aServer:aPort
    // - optionaly via TLS (using the SChannel API on Windows, or by including
    // mormot.lib.openssl11 unit to your project) - with custom input options
    // - aTunnel could be populated from mormot.net.client GetSystemProxyUri()
    // - see also SocketOpen() for a wrapper catching any connection exception
    constructor Open(const aServer, aPort: RawUtf8; aLayer: TNetLayer = nlTcp;
      aTimeOut: cardinal = 10000; aTLS: boolean = false;
      aTLSContext: PNetTlsContext = nil; aTunnel: PUri = nil);
    /// high-level constructor to connect to a given URI
    constructor OpenUri(const aUri: RawUtf8; out aAddress: RawUtf8;
      const aTunnel: RawUtf8 = ''; aTimeOut: cardinal = 10000;
      aTLSContext: PNetTlsContext = nil); overload;
    /// constructor to bind to an address
    // - aAddr='1234' - bind to a port on all interfaces, the same as '0.0.0.0:1234'
    // - aAddr='IP:port' - bind to specified interface only, e.g.
    // '1.2.3.4:1234'
    // - aAddr='unix:/path/to/file' - bind to unix domain socket, e.g.
    // 'unix:/run/mormot.sock'
    // - aAddr='' - bind to systemd descriptor on linux - see
    // http://0pointer.de/blog/projects/socket-activation.html
    constructor Bind(const aAddress: RawUtf8; aLayer: TNetLayer = nlTcp;
      aTimeOut: integer = 10000);
    /// low-level internal method called by Open() and Bind() constructors
    // - raise an ENetSock exception on error
    // - optionaly via TLS (using the SChannel API on Windows, or by including
    // mormot.lib.openssl11 unit) - with custom input options in the TLS fields
    procedure OpenBind(const aServer, aPort: RawUtf8; doBind: boolean;
      aTLS: boolean = false; aLayer: TNetLayer = nlTcp;
      aSock: TNetSocket = TNetSocket(-1));
    /// initialize the instance with the supplied accepted socket
    // - is called from a bound TCP Server, just after Accept()
    procedure AcceptRequest(aClientSock: TNetSocket; aClientAddr: PNetAddr);
    /// low-level TLS support method
    procedure DoTlsAfter(caller: TCrtSocketTlsAfter);
    /// initialize SockIn for receiving with read[ln](SockIn^,...)
    // - data is buffered, filled as the data is available
    // - read(char) or readln() is indeed very fast
    // - multithread applications would also use this SockIn pseudo-text file
    // - default 1KB is big enough for headers (content will be read directly)
    // - by default, expect CR+LF as line feed (i.e. the HTTP way)
    procedure CreateSockIn(LineBreak: TTextLineBreakStyle = tlbsCRLF;
      InputBufferSize: integer = 1024);
    /// initialize SockOut for sending with write[ln](SockOut^,....)
    // - data is sent (flushed) after each writeln() - it's a compiler feature
    // - use rather SockSend() + SockSendFlush to send headers at once e.g.
    // since writeln(SockOut^,..) flush buffer each time
    procedure CreateSockOut(OutputBufferSize: integer = 1024);
    /// finalize SockIn receiving buffer
    // - you may call this method when you are sure that you don't need the
    // input buffering feature on this connection any more (e.g. after having
    // parsed the HTTP header, then rely on direct socket comunication)
    procedure CloseSockIn;
    /// finalize SockOut receiving buffer
    // - you may call this method when you are sure that you don't need the
    // output buffering feature on this connection any more (e.g. after having
    // parsed the HTTP header, then rely on direct socket comunication)
    procedure CloseSockOut;
    /// close and shutdown the connection
    // - called from Destroy, but is reintrant so could be called earlier
    procedure Close; virtual;
    /// close the opened socket, and corresponding SockIn/SockOut
    destructor Destroy; override;
    /// read Length bytes from SockIn buffer + Sock if necessary
    // - if SockIn is available, it first gets data from SockIn^.Buffer,
    // then directly receive data from socket if UseOnlySockIn = false
    // - if UseOnlySockIn = true, it will return the data available in SockIn^,
    // and returns the number of bytes
    // - can be used also without SockIn: it will call directly SockRecv()
    // in such case (assuming UseOnlySockin=false)
    function SockInRead(Content: PAnsiChar; Length: integer;
      UseOnlySockIn: boolean = false): integer;
    /// returns the number of bytes in SockIn buffer or pending in Sock
    // - if SockIn is available, it first check from any data in SockIn^.Buffer,
    // then call InputSock to try to receive any pending data if the buffer is void
    // - if aPendingAlsoInSocket is TRUE, returns the bytes available in both the buffer
    // and the socket (sometimes needed, e.g. to process a whole block at once)
    // - will wait up to the specified aTimeOutMS value (in milliseconds) for
    // incoming data - may wait a little less time on Windows due to a select bug
    // - returns -1 in case of a socket error (e.g. broken/closed connection);
    // you can raise a ENetSock exception to propagate the error
    function SockInPending(aTimeOutMS: integer;
      aPendingAlsoInSocket: boolean = false): integer;
    /// checks if the low-level socket handle has been assigned
    // - just a wrapper around PtrInt(fSock)>0
    function SockIsDefined: boolean;
      {$ifdef HASINLINE}inline;{$endif}
    /// check the connection status of the socket
    function SockConnected: boolean;
    /// simulate writeln() with direct use of Send(Sock, ..) - includes trailing #13#10
    // - useful on multi-treaded environnement (as in THttpServer.Process)
    // - no temp buffer is used
    // - handle RawByteString, ShortString, Char, integer parameters
    // - raise ENetSock exception on socket error
    procedure SockSend(const Values: array of const); overload;
    /// simulate writeln() with a single line - includes trailing #13#10
    procedure SockSend(const Line: RawByteString; NoCrLf: boolean = false); overload;
    /// append P^ data into SndBuf (used by SockSend(), e.g.) - no trailing #13#10
    // - call SockSendFlush to send it through the network via SndLow()
    procedure SockSend(P: pointer; Len: integer); overload;
    /// append #13#10 characters
    procedure SockSendCRLF;
    /// flush all pending data to be sent, optionally with some body content
    // - raise ENetSock on error
    procedure SockSendFlush(const aBody: RawByteString = '');
    /// send all TStream content till the end using SndLow()
    // - don't forget to call SockSendFlush before using this method
    // - will call Stream.Read() over a temporary buffer of 1MB by default
    // - Stream may be a TFileStream, THttpMultiPartStream or TNestedStreamReader
    // - raise ENetSock on error
    procedure SockSendStream(Stream: TStream; ChunkSize: integer = 1 shl 20);
    /// how many bytes could be added by SockSend() in the internal buffer
    function SockSendRemainingSize: integer;
      {$ifdef HASINLINE}inline;{$endif}
    /// fill the Buffer with Length bytes
    // - use TimeOut milliseconds wait for incoming data
    // - bypass the SockIn^ buffers
    // - raise ENetSock exception on socket error
    procedure SockRecv(Buffer: pointer; Length: integer);
    /// check if there are some pending bytes in the input sockets API buffer
    // - returns cspSocketError if the connection is broken or closed
    // - warning: on Windows, may wait a little less than TimeOutMS (select bug)
    function SockReceivePending(TimeOutMS: integer;
      loerr: system.PInteger = nil): TCrtSocketPending;
    /// returns the socket input stream as a string
    function SockReceiveString: RawByteString;
    /// fill the Buffer with Length bytes
    // - use TimeOut milliseconds wait for incoming data
    // - bypass the SockIn^ buffers
    // - return false on any fatal socket error, true on success
    // - call Close if the socket is identified as shutdown from the other side
    // - you may optionally set StopBeforeLength = true, then the read bytes count
    // are set in Length, even if not all expected data has been received - in
    // this case, Close method won't be called
    function TrySockRecv(Buffer: pointer; var Length: integer;
      StopBeforeLength: boolean = false): boolean;
    /// call readln(SockIn^,Line) or simulate it with direct use of Recv(Sock, ..)
    // - char are read one by one if needed
    // - use TimeOut milliseconds wait for incoming data
    // - raise ENetSock exception on socket error
    // - by default, will handle #10 or #13#10 as line delimiter (as normal text
    // files), but you can delimit lines using #13 if CROnly is TRUE
    procedure SockRecvLn(out Line: RawUtf8; CROnly: boolean = false); overload;
    /// call readln(SockIn^) or simulate it with direct use of Recv(Sock, ..)
    // - char are read one by one
    // - use TimeOut milliseconds wait for incoming data
    // - raise ENetSock exception on socket error
    // - line content is ignored
    procedure SockRecvLn; overload;
    /// direct send data through network
    // - raise a ENetSock exception on any error
    // - bypass the SockSend() or SockOut^ buffers
    procedure SndLow(P: pointer; Len: integer); overload;
    /// direct send data through network
    // - raise a ENetSock exception on any error
    // - bypass the SndBuf or SockOut^ buffers
    // - raw Data is sent directly to OS: no LF/CRLF is appened to the block
    procedure SndLow(const Data: RawByteString); overload;
    /// direct send data through network
    // - return false on any error, true on success
    // - bypass the SndBuf or SockOut^ buffers
    function TrySndLow(P: pointer; Len: integer): boolean;
    /// returns the low-level error number
    // - i.e. returns WSAGetLastError
    function LastLowSocketError: integer;
    /// direct accept an new incoming connection on a bound socket
    // - instance should have been setup as a server via a previous Bind() call
    // - returns nil on error or a ResultClass instance on success
    // - if ResultClass is nil, will return a plain TCrtSocket, but you may
    // specify e.g. THttpServerSocket if you expect incoming HTTP requests
    function AcceptIncoming(ResultClass: TCrtSocketClass = nil;
      Async: boolean = false): TCrtSocket;
    /// remote IP address after AcceptRequest() call over TCP
    // - is either the raw connection IP to the current server socket, or
    // a custom header value set by a local proxy as retrieved by inherited
    // THttpServerSocket.GetRequest, searching the header named in
    // THttpServerGeneric.RemoteIPHeader (e.g. 'X-Real-IP' for nginx)
    property RemoteIP: RawUtf8
      read fRemoteIP write fRemoteIP;
    /// remote IP address of the last packet received (SocketLayer=slUDP only)
    function PeerAddress(LocalAsVoid: boolean = false): RawUtf8;
    /// remote IP port of the last packet received (SocketLayer=slUDP only)
    function PeerPort: TNetPort;
    /// set the TCP_NODELAY option for the connection
    // - default true will disable the Nagle buffering algorithm; it should
    // only be set for applications that send frequent small bursts of information
    // without getting an immediate response, where timely delivery of data
    // is required - so it expects buffering before calling Write() or SndLow()
    // - you can set false here to enable the Nagle algorithm, if needed
    // - see http://www.unixguide.net/network/socketfaq/2.16.shtml
    property TcpNoDelay: boolean
      write SetTcpNoDelay;
    /// set the SO_SNDTIMEO option for the connection
    // - i.e. the timeout, in milliseconds, for blocking send calls
    // - see http://msdn.microsoft.com/en-us/library/windows/desktop/ms740476
    property SendTimeout: integer
      write SetSendTimeout;
    /// set the SO_RCVTIMEO option for the connection
    // - i.e. the timeout, in milliseconds, for blocking receive calls
    // - see http://msdn.microsoft.com/en-us/library/windows/desktop/ms740476
    property ReceiveTimeout: integer
      write SetReceiveTimeout;
    /// set the SO_KEEPALIVE option for the connection
    // - 1 (true) will enable keep-alive packets for the connection
    // - see http://msdn.microsoft.com/en-us/library/windows/desktop/ee470551
    property KeepAlive: boolean
      write SetKeepAlive;
    /// set the SO_LINGER option for the connection, to control its shutdown
    // - by default (or Linger<0), Close will return immediately to the caller,
    // and any pending data will be delivered if possible
    // - Linger > 0  represents the time in seconds for the timeout period
    // to be applied at Close; under Linux, will also set SO_REUSEADDR; under
    // Darwin, set SO_NOSIGPIPE
    // - Linger = 0 causes the connection to be aborted and any pending data
    // is immediately discarded at Close
    property Linger: integer
      write SetLinger;
    /// low-level socket handle, initialized after Open() with socket
    property Sock: TNetSocket
      read fSock write fSock;
    /// after CreateSockIn, use Readln(SockIn^,s) to read a line from the opened socket
    property SockIn: PTextFile
      read fSockIn;
    /// after CreateSockOut, use Writeln(SockOut^,s) to send a line to the opened socket
    property SockOut: PTextFile
      read fSockOut;
  published
    /// low-level socket type, initialized after Open() with socket
    property SocketLayer: TNetLayer
      read fSocketLayer;
    /// IP address, initialized after Open() with Server name
    property Server: RawUtf8
      read fServer;
    /// IP port, initialized after Open() with port number
    property Port: RawUtf8
      read fPort;
    /// contains Sock, but transtyped as number for log display
    property RawSocket: PtrInt
      read GetRawSocket;
    /// HTTP Proxy URI used for tunnelling, from Tunnel.Server/Port values
    property ProxyUrl: RawUtf8
      read fProxyUrl;
    /// if higher than 0, read loop will wait for incoming data till
    // TimeOut milliseconds (default value is 10000) - used also in SockSend()
    property TimeOut: PtrInt
      read fTimeOut;
    /// total bytes received
    property BytesIn: Int64
      read fBytesIn write fBytesIn;
    /// total bytes sent
    property BytesOut: Int64
      read fBytesOut write fBytesOut;
  end;
  {$M-}


/// create a TCrtSocket instance, returning nil on error
// - useful to easily catch any exception, and provide a custom TNetTlsContext
// - aTunnel could be populated from mormot.net.client GetSystemProxyUri()
function SocketOpen(const aServer, aPort: RawUtf8;
  aTLS: boolean = false; aTLSContext: PNetTlsContext = nil;
  aTunnel: PUri = nil): TCrtSocket;



implementation

{ ******** System-Specific Raw Sockets API Layer }

{ includes are below inserted just after 'implementation' keyword to allow
  their own private 'uses' clause }

{$ifdef OSWINDOWS}
  {$I mormot.net.sock.windows.inc}
{$endif OSWINDOWS}

{$ifdef OSPOSIX}
  {$I mormot.net.sock.posix.inc}
{$endif OSPOSIX}

const
  // don't use RTTI to avoid mormot.core.rtti.pas and have better spelling
  _NR: array[TNetResult] of string[20] = (
    'Ok',
    'Retry',
    'No Socket',
    'Not Found',
    'Not Implemented',
    'Closed',
    'Fatal Error',
    'Unknown Error',
    'Too Many Connections',
    'Refused',
    'Connect Timeout');

function NetLastError(AnotherNonFatal: integer; Error: system.PInteger): TNetResult;
var
  err: integer;
begin
  err := sockerrno;
  if Error <> nil then
    Error^ := err;
  if err = NO_ERROR then
    result := nrOK
  else if {$ifdef OSWINDOWS}
          (err <> WSAETIMEDOUT) and
          (err <> WSAEWOULDBLOCK) and
          {$endif OSWINDOWS}
          (err <> WSATRY_AGAIN) and
          (err <> AnotherNonFatal) then
    if err = WSAEMFILE then
      result := nrTooManyConnections
    else if err = WSAECONNREFUSED then
      result := nrRefused
    {$ifdef OSLINUX}
    else if err = ESysEPIPE then
      result := nrClosed
    {$endif OSLINUX}
    else
      result := nrFatalError
  else
    result := nrRetry;
end;

function NetLastErrorMsg(AnotherNonFatal: integer): ShortString;
var
  nr: TNetResult;
  err: integer;
begin
  nr := NetLastError(AnotherNonFatal, @err);
  str(err, result);
  result := _NR[nr] + ' ' + result;
end;

function NetCheck(res: integer): TNetResult;
  {$ifdef HASINLINE}inline;{$endif}
begin
  if res = NO_ERROR then
    result := nrOK
  else
    result := NetLastError;
end;

function ToText(res: TNetResult): PShortString;
begin
  result := @_NR[res]; // no mormot.core.rtti.pas need
end;


{ ENetSock }

constructor ENetSock.Create(msg: string; const args: array of const;
  error: TNetResult);
begin
  fLastError := error;
  if error <> nrOK then
    msg := format('%s [%s - #%d]', [msg, _NR[error], ord(error)]);
  inherited CreateFmt(msg, args);
end;

class procedure ENetSock.Check(res: TNetResult; const Context: ShortString);
begin
  if (res <> nrOK) and
     (res <> nrRetry) then
    raise Create('%s failed', [Context], res);
end;

class procedure ENetSock.CheckLastError(const Context: ShortString;
  ForceRaise: boolean; AnotherNonFatal: integer);
var
  res: TNetResult;
begin
  res := NetLastError(AnotherNonFatal);
  if ForceRaise and
     (res in [nrOK, nrRetry]) then
    res := nrUnknownError;
  Check(res, Context);
end;



{ ******** TNetAddr Cross-Platform Wrapper }

{ TNetAddr }

function TNetAddr.Family: TNetFamily;
begin
  case PSockAddr(@Addr)^.sa_family of
    AF_INET:
      result := nfIP4;
    AF_INET6:
      result := nfIP6;
    {$ifdef OSPOSIX}
    AF_UNIX:
      result := nfUnix;
    {$endif OSPOSIX}
  else
    result := nfUnknown;
  end;
end;

procedure TNetAddr.IP(var res: RawUtf8; localasvoid: boolean);
begin
  res := '';
  case PSockAddr(@Addr)^.sa_family of
    AF_INET:
      IP4Text(@PSockAddr(@Addr)^.sin_addr, res); // detect 0.0.0.0 and 127.0.0.1
    AF_INET6:
      IP6Text(@PSockAddrIn6(@Addr)^.sin6_addr, res); // detect :: and ::1
    {$ifdef OSPOSIX}
    AF_UNIX:
      begin
        if not localasvoid then
          res := IP4local; // by definition, unix sockets are local
        exit;
      end;
    {$endif OSPOSIX}
  else
    exit;
  end;
  if localasvoid and
     (pointer(res) = pointer(IP4local)) then
    res := '';
end;

function TNetAddr.IP(localasvoid: boolean): RawUtf8;
begin
  IP(result, localasvoid);
end;

function TNetAddr.IP4: cardinal;
begin
  with PSockAddr(@Addr)^ do
    if sa_family = AF_INET then
      result := cardinal(sin_addr) // may return cLocalhost32 = 127.0.0.1
    else
      result := 0; // AF_INET6 or AF_UNIX returns 0
end;

function TNetAddr.IPShort(withport: boolean): ShortString;
begin
  IPShort(result, withport);
end;

procedure TNetAddr.IPShort(out result: ShortString; withport: boolean);
begin
  result[0] := #0;
  case PSockAddr(@Addr)^.sa_family of
    AF_INET:
      IP4Short(@PSockAddr(@Addr)^.sin_addr, result);
    AF_INET6:
      IP6Short(@PSockAddrIn6(@Addr)^.sin6_addr, result);
    {$ifdef OSPOSIX}
    AF_UNIX:
      begin
        SetString(result, PAnsiChar(@psockaddr_un(@Addr)^.sun_path),
          mormot.core.base.StrLen(@psockaddr_un(@Addr)^.sun_path));
        exit; // no port
      end;
    {$endif OSPOSIX}
  else
    exit;
  end;
  if withport then
  begin
    AppendShortChar(':', result);
    AppendShortCardinal(port, result);
  end;
end;

function TNetAddr.IPWithPort: RawUtf8;
var
  tmp: shortstring;
begin
  IPShort(tmp, {withport=}true);
  ShortStringToAnsi7String(tmp, result);
end;

function TNetAddr.Port: TNetPort;
begin
  with PSockAddr(@Addr)^ do
    if sa_family in [AF_INET, AF_INET6] then
      result := htons(sin_port)
    else
      result := 0;
end;

function TNetAddr.SetPort(p: TNetPort): TNetResult;
begin
  with PSockAddr(@Addr)^ do
    if (sa_family in [AF_INET, AF_INET6]) and
       (p <= 65535) then
    begin
      sin_port := htons(p);
      result := nrOk;
    end
    else
      result := nrNotFound;
end;

function TNetAddr.Size: integer;
begin
  case PSockAddr(@Addr)^.sa_family of
    AF_INET:
      result := SizeOf(sockaddr_in);
    AF_INET6:
      result := SizeOf(sockaddr_in6);
  else
    result := SizeOf(Addr);
  end;
end;

function TNetAddr.IsEqualAfter64(const another: TNetAddr): boolean;
begin
  case PSockAddr(@Addr)^.sa_family of
    AF_INET:
      result := true; // SizeOf(sockaddr_in) = SizeOf(Int64) = 8
    AF_INET6:
      result := CompareMemFixed(@Addr[8], @another.Addr[8], SizeOf(sockaddr_in6) - 8)
  else
    result := false;
  end;
end;

function TNetAddr.IsEqual(const another: TNetAddr): boolean;
begin
  if PInt64(@Addr)^ = PInt64(@another)^ then
    result := IsEqualAfter64(another)
  else
    result := false;
end;

function TNetAddr.NewSocket(layer: TNetLayer): TNetSocket;
var
  s: TSocket;
begin
  s := socket(PSockAddr(@Addr)^.sa_family, _ST[layer], _IP[layer]);
  if s < 0 then
    result := nil
  else
    result := TNetSocket(s);
end;


{ ******** TNetSocket Cross-Platform Wrapper }

function GetSocketAddressFromCache(const address, port: RawUtf8; layer: TNetLayer;
  out addr: TNetAddr; var fromcache, tobecached: boolean): TNetResult;
var
  p: cardinal;
begin
  fromcache := false;
  tobecached := false;
  if (layer in nlIP) and
     Assigned(NewSocketAddressCache) and
     ToCardinal(port, p, 1) then
    if (address = '') or
       (address = cLocalhost) or
       (address = cAnyHost) then // for client: '0.0.0.0'->'127.0.0.1'
      result := addr.SetFrom(cLocalhost, port, layer)
    else if NewSocketAddressCache.Search(address, addr) then
    begin
      fromcache := true;
      result := addr.SetPort(p);
    end
    else
    begin
      tobecached := true;
      result := addr.SetFrom(address, port, layer);
    end
  else
    result := addr.SetFrom(address, port, layer);
end;

function GetReachableNetAddr(const address, port: array of RawUtf8;
  timeoutms, neededcount: integer; sockets: PNetSocketDynArray): TNetAddrDynArray;
var
  i, n: PtrInt;
  s: TNetSocket;
  sock: TNetSocketDynArray;
  addr: TNetAddrDynArray;
  res: TNetResult;
  tix: Int64;
begin
  result := nil;
  if sockets <> nil then
    sockets^ := nil;
  if neededcount <= 0 then
    exit;
  n := length(address);
  if (n = 0) or
     (length(port) <> n) then
    exit;
  SetLength(sock, n);
  SetLength(addr, n);
  n := 0;
  for i := 0 to length(sock) - 1 do
  begin
    res := addr[n].SetFrom(address[i], port[i], nlTcp); // bypass DNS cache here
    if res <> nrOK then
      continue;
    s := addr[n].NewSocket(nlTcp);
    if (s = nil) or
       (s.MakeAsync <> nrOk) then
      continue;
    connect(s.Socket, @addr[n], addr[n].Size); // non-blocking connect() once
    if s.MakeBlocking <> nrOk then
      continue;
    sock[n] := s;
    inc(n);
  end;
  if n = 0 then
    exit;
  if neededcount > n then
    neededcount := n;
  SetLength(result, n);
  if sockets <> nil then
    SetLength(sockets^, n);
  n := 0;
  tix := mormot.core.os.GetTickCount64 + timeoutms;
  repeat
    for i := 0 to length(result) - 1 do
      if (sock[i] <> nil) and
         (sock[i].WaitFor(1, [neWrite]) = [neWrite]) then
      begin
        if sockets = nil then
          sock[i].ShutdownAndClose(false)
        else
          sockets^[n] := sock[i]; // let caller own this socket from now on
        sock[i] := nil; // mark this socket as closed
        result[n] := addr[i];
        inc(n);
        dec(neededcount);
        if neededcount = 0 then
          break;
      end;
  until (neededcount = 0) or
        (mormot.core.os.GetTickCount64 > tix);
  if n <> length(result) then
  begin
    for i := 0 to length(result) - 1 do
      if sock[i] <> nil then
        sock[i].ShutdownAndClose(false);
    SetLength(result, n);
    if sockets <> nil then
      SetLength(sockets^, n);
  end;
end;

function NewSocket(const address, port: RawUtf8; layer: TNetLayer;
  dobind: boolean; connecttimeout, sendtimeout, recvtimeout, retry: integer;
  out netsocket: TNetSocket; netaddr: PNetAddr): TNetResult;
var
  addr: TNetAddr;
  sock: TNetSocket;
  fromcache, tobecached: boolean;
  connectendtix: Int64;
begin
  netsocket := nil;
  // resolve the TNetAddr of the address:port layer - maybe from cache
  fromcache := false;
  tobecached := false;
  if dobind then
    result := addr.SetFrom(address, port, layer)
  else
    result := GetSocketAddressFromCache(
      address, port, layer, addr, fromcache, tobecached);
  if result <> nrOK then
    exit;
  // create the raw Socket instance
  sock := addr.NewSocket(layer);
  if sock = nil then
  begin
    result := NetLastError(WSAEADDRNOTAVAIL);
    if fromcache then
      // force call the DNS resolver again, perhaps load-balacing is needed
      NewSocketAddressCache.Flush(address);
    exit;
  end;
  // bind or connect to this Socket
  {$ifdef OSWINDOWS}
  if not dobind then
  begin // on Windows, default buffers are of 8KB :(
    sock.SetRecvBufferSize(65536);
    sock.SetSendBufferSize(65536);
  end; // to be done before the actual connect() for proper TCP negotiation
  {$endif OSWINDOWS}
  // open non-blocking Client connection if a timeout was specified
  if (connecttimeout > 0) and
     not dobind then
  begin
    // SetReceiveTimeout/SetSendTimeout don't apply to connect() -> async
    if connecttimeout < 100 then
      connectendtix := 0
    else
      connectendtix := mormot.core.os.GetTickCount64 + connecttimeout;
    sock.MakeAsync;
    connect(sock.Socket, @addr, addr.Size); // non-blocking connect() once
    sock.MakeBlocking;
    result := nrConnectTimeout;
    repeat
      if sock.WaitFor(1, [neWrite]) = [neWrite] then
      begin
        result := nrOK;
        break;
      end;
      SleepHiRes(1); // wait for actual connection
    until (connectendtix = 0) or
          (mormot.core.os.GetTickCount64 > connectendtix);
  end
  else
  repeat
    if dobind then
    begin
      // bound Socket should remain open for 5 seconds after a closesocket()
      if layer <> nlUdp then
        sock.SetLinger(5);
      // Server-side binding/listening of the socket to the address:port
      if (bind(sock.Socket, @addr, addr.Size) <> NO_ERROR) or
         ((layer <> nlUdp) and
          (listen(sock.Socket, DefaultListenBacklog) <> NO_ERROR)) then
        result := NetLastError(WSAEADDRNOTAVAIL);
    end
    else
      // open blocking Client connection (use system-defined timeout)
      if connect(sock.Socket, @addr, addr.Size) <> NO_ERROR then
        result := NetLastError(WSAEADDRNOTAVAIL);
    if (result = nrOK) or
       (retry <= 0) then
      break;
    dec(retry);
    SleepHiRes(10);
  until false;
  if result <> nrOK then
  begin
    // this address:port seems invalid or already bound
    closesocket(sock.Socket);
    if fromcache then
      // ensure the cache won't contain this faulty address any more
      NewSocketAddressCache.Flush(address);
  end
  else
  begin
    // Socket is successfully connected -> setup the connection
    if tobecached then
      // update cache once we are sure the host actually exists
      NewSocketAddressCache.Add(address, addr);
    netsocket := sock;
    netsocket.SetupConnection(layer, sendtimeout, recvtimeout);
    if netaddr <> nil then
      MoveFast(addr, netaddr^, addr.Size);
  end;
end;


{ TNetSocketWrap }

procedure TNetSocketWrap.SetOpt(prot, name: integer;
  value: pointer; valuelen: integer);
var
  err: TNetResult;
  low: integer;
begin
  if @self = nil then
    raise ENetSock.Create('SetOptions(%d,%d) with no socket', [prot, name]);
  if setsockopt(TSocket(@self), prot, name, value, valuelen) = NO_ERROR then
    exit;
  err := NetLastError(NO_ERROR, @low);
  raise ENetSock.Create('SetOptions(%d,%d) sockerr=%d', [prot, name, low], err);
end;

function TNetSocketWrap.GetOptInt(prot, name: integer): integer;
var
  len: integer;
begin
  if @self = nil then
    raise ENetSock.Create('GetOptInt(%d,%d) with no socket', [prot, name]);
  result := 0;
  len := SizeOf(result);
  if getsockopt(TSocket(@self), prot, name, @result, @len) <> NO_ERROR then
    raise ENetSock.Create('GetOptInt(%d,%d)', [prot, name], NetLastError);
end;

procedure TNetSocketWrap.SetKeepAlive(keepalive: boolean);
var
  v: integer;
begin
  v := ord(keepalive);
  SetOpt(SOL_SOCKET, SO_KEEPALIVE, @v, SizeOf(v));
end;

procedure TNetSocketWrap.SetNoDelay(nodelay: boolean);
var
  v: integer;
begin
  v := ord(nodelay);
  SetOpt(IPPROTO_TCP, TCP_NODELAY, @v, SizeOf(v));
end;

procedure TNetSocketWrap.SetSendBufferSize(bytes: integer);
begin
  SetOpt(SOL_SOCKET, SO_SNDBUF, @bytes, SizeOf(bytes));
end;

procedure TNetSocketWrap.SetRecvBufferSize(bytes: integer);
begin
  SetOpt(SOL_SOCKET, SO_RCVBUF, @bytes, SizeOf(bytes));
end;

function TNetSocketWrap.GetSendBufferSize: integer;
begin
  result := GetOptInt(SOL_SOCKET, SO_SNDBUF);
  // typical value on Linux is 2626560 bytes for TCP (16384 for accept),
  // 212992 for Unix socket - on Windows, default is 8192
end;

function TNetSocketWrap.GetRecvBufferSize: integer;
begin
  result := GetOptInt(SOL_SOCKET, SO_RCVBUF);
  // typical value on Linux is 131072 bytes for TCP, 212992 for Unix socket
  // - on Windows, default is 8192
end;

procedure TNetSocketWrap.SetupConnection(layer: TNetLayer;
  sendtimeout, recvtimeout: integer);
begin
  if @self = nil then
    exit;
  if sendtimeout > 0 then
    SetSendTimeout(sendtimeout);
  if recvtimeout > 0 then
    SetReceiveTimeout(recvtimeout);
  if layer = nlTcp then
  begin
    SetNoDelay(true);   // disable Nagle algorithm (we use our own buffers)
    SetKeepAlive(true); // enabled TCP keepalive
  end;
end;

function TNetSocketWrap.Accept(out clientsocket: TNetSocket;
  out addr: TNetAddr; async: boolean): TNetResult;
var
  sock: TSocket;
begin
  if @self = nil then
    result := nrNoSocket
  else
  begin
    sock := doaccept(TSocket(@self), @addr, async);
    if sock = -1 then
    begin
      result := NetLastError;
      if result = nrOk then
        result := nrNotImplemented;
    end
    else
    begin
      clientsocket := TNetSocket(sock);
      {$ifdef OSWINDOWS}
      // on Windows, default buffers are of 8KB :(
      clientsocket.SetRecvBufferSize(65536);
      clientsocket.SetSendBufferSize(65536);
      {$endif OSWINDOWS}
      if async then
        result := clientsocket.MakeAsync
      else
        result := nrOK;
    end;
  end;
end;

function TNetSocketWrap.GetPeer(out addr: TNetAddr): TNetResult;
var
  len: tsocklen;
begin
  FillCharFast(addr, SizeOf(addr), 0);
  if @self = nil then
    result := nrNoSocket
  else
  begin
    len := SizeOf(addr);
    result := NetCheck(getpeername(TSocket(@self), @addr, len));
  end;
end;

function TNetSocketWrap.SetIoMode(async: cardinal): TNetResult;
begin
  if @self = nil then
    result := nrNoSocket
  else
    result := NetCheck(ioctlsocket(TSocket(@self), FIONBIO, @async));
end;

function TNetSocketWrap.MakeAsync: TNetResult;
begin
  result := SetIoMode(1);
end;

function TNetSocketWrap.MakeBlocking: TNetResult;
begin
  result := SetIoMode(0);
end;

function TNetSocketWrap.Send(Buf: pointer; var len: integer): TNetResult;
begin
  if @self = nil then
    result := nrNoSocket
  else
  begin
    len := mormot.net.sock.send(TSocket(@self), Buf, len, MSG_NOSIGNAL);
    // man send: Upon success, send() returns the number of bytes sent.
    // Otherwise, -1 is returned and errno set to indicate the error.
    if len < 0 then
      result := NetLastError
    else
      result := nrOK;
  end;
end;

function TNetSocketWrap.Recv(Buf: pointer; var len: integer): TNetResult;
begin
  if @self = nil then
    result := nrNoSocket
  else
  begin
    len := mormot.net.sock.recv(TSocket(@self), Buf, len, 0);
    // man recv: Upon successful completion, recv() shall return the length of
    // the message in bytes. If no messages are available to be received and the
    // peer has performed an orderly shutdown, recv() shall return 0.
    // Otherwise, -1 shall be returned and errno set to indicate the error,
    // which may be nrRetry if no data is available.
    if len <= 0 then
      if len = 0 then
        result := nrClosed
      else
        result := NetLastError
    else
      result := nrOK;
  end;
end;

function TNetSocketWrap.SendTo(Buf: pointer; len: integer;
  const addr: TNetAddr): TNetResult;
begin
  if @self = nil then
    result := nrNoSocket
  else if mormot.net.sock.sendto(TSocket(@self), Buf, len, 0, @addr, SizeOf(addr)) < 0 then
    result := NetLastError
  else
    result := nrOk;
end;

function TNetSocketWrap.RecvFrom(Buf: pointer; len: integer; out addr: TNetAddr): integer;
var
  addrlen: integer;
begin
  if @self = nil then
    result := -1
  else
  begin
    addrlen := SizeOf(addr);
    result := mormot.net.sock.recvfrom(TSocket(@self), Buf, len, 0, @addr, @addrlen);
  end;
end;

function TNetSocketWrap.RecvPending(out pending: integer): TNetResult;
begin
  if @self = nil then
  begin
    pending := 0;
    result := nrNoSocket;
  end
  else
    result := NetCheck(ioctlsocket(TSocket(@self), FIONREAD, @pending));
end;

function TNetSocketWrap.RecvWait(ms: integer;
  out data: RawByteString; terminated: PTerminated): TNetResult;
var
  events: TNetEvents;
  pending: integer;
begin
  events := WaitFor(ms, [neRead]);
  if (neError in events) or
     (Assigned(terminated) and
      terminated^) then
    result := nrClosed
  else if neRead in events then
  begin
    result := RecvPending(pending);
    if result = nrOK then
      if pending > 0 then
      begin
        SetLength(data, pending);
        result := Recv(pointer(data), pending);
        if Assigned(terminated) and
           terminated^ then
          result := nrClosed;
        if result <> nrOK then
          exit;
        if pending <= 0 then
        begin
          result := nrUnknownError;
          exit;
        end;
        if pending <> length(data) then
          SetLength(data, pending);
      end
      else
        result := nrRetry;
  end
  else
    result := nrRetry;
end;

function TNetSocketWrap.SendAll(Buf: PByte; len: integer;
  terminated: PTerminated): TNetResult;
var
  sent: integer;
begin
  repeat
    sent := len;
    result := Send(Buf, len);
    if Assigned(terminated) and
       terminated^ then
      break;
    if sent > 0 then
    begin
      inc(Buf, sent);
      dec(len, sent);
      if len = 0 then
        exit;
    end;
    if result <> nrRetry then
      exit;
    SleepHiRes(1);
  until Assigned(terminated) and
        terminated^;
  result := nrClosed;
end;

function TNetSocketWrap.ShutdownAndClose(rdwr: boolean): TNetResult;
const
  SHUT_: array[boolean] of integer = (
    SHUT_RD, SHUT_RDWR);
begin
  if @self = nil then
    result := nrNoSocket
  else
  begin
    {$ifdef OSLINUX}
    // on Linux close() is enough after accept (e.g. nginx don't call shutdown)
    if rdwr then
    {$endif OSLINUX}
      shutdown(TSocket(@self), SHUT_[rdwr]);
    result := Close;
  end;
end;

function TNetSocketWrap.Close: TNetResult;
begin
  if @self = nil then
    result := nrNoSocket
  else
  begin
    closesocket(TSocket(@self)); // SO_LINGER usually set to 5 or 10 seconds
    result := nrOk;
  end;
end;

function TNetSocketWrap.Socket: PtrInt;
begin
  result := TSocket(@self);
end;


{ ******************** Mac and IP Addresses Support }

const // should be local for better code generation
  HexCharsLower: array[0..15] of AnsiChar = '0123456789abcdef';

function IsPublicIP(ip4: cardinal): boolean;
begin
  result := false;
  case ToByte(ip4) of // ignore IANA private IP4 address spaces
    10:
      exit;
    172:
      if ((ip4 shr 8) and 255) in [16..31] then
        exit;
    192:
      if (ip4 shr 8) and 255 = 168 then
        exit;
  end;
  result := true;
end;

procedure IP4Short(ip4addr: PByteArray; var s: ShortString);
begin
  s[0] := #0;
  AppendShortCardinal(ip4addr[0], s);
  inc(s[0]);
  s[ord(s[0])] := '.';
  AppendShortCardinal(ip4addr[1], s);
  inc(s[0]);
  s[ord(s[0])] := '.';
  AppendShortCardinal(ip4addr[2], s);
  inc(s[0]);
  s[ord(s[0])] := '.';
  AppendShortCardinal(ip4addr[3], s);
  PAnsiChar(@s)[ord(s[0]) + 1] := #0; // make #0 terminated (won't hurt)
end;

procedure IP4Text(ip4addr: PByteArray; var result: RawUtf8);
var
  s: ShortString;
begin
  if PCardinal(ip4addr)^ = 0 then
    // '0.0.0.0' bound to any host -> ''
    result := ''
  else if PCardinal(ip4addr)^ = cLocalhost32 then
    // '127.0.0.1' loopback (no memory allocation)
    result := IP4local
  else
  begin
    IP4Short(ip4addr, s);
    FastSetString(result, @s[1], ord(s[0]));
  end;
end;

procedure IP6Short(ip6addr: PByteArray; var s: ShortString);
// this code is faster than any other inet_ntop6() I could find around
var
  i: PtrInt;
  trimlead: boolean;
  c, n: byte;
  p: PAnsiChar;
  zeros, current: record pos, len: ShortInt; end;
  tab: PAnsiChar;
begin
  // find longest run of 0000: for :: shortening
  zeros.pos := -1;
  zeros.len := 0;
  current.pos := -1;
  current.len := 0;
  for i := 0 to 7 do
    if PWordArray(ip6addr)[i] = 0 then
      if current.pos < 0 then
      begin
        current.pos := i;
        current.len := 1;
      end
      else
        inc(current.len)
    else if current.pos >= 0 then
    begin
      if (zeros.pos < 0) or
         (current.len > zeros.len) then
        zeros := current;
      current.pos := -1;
    end;
  if (current.pos >= 0) and
     ((zeros.pos < 0) or
      (current.len > zeros.len)) then
    zeros := current;
  if (zeros.pos >= 0) and
     (zeros.len < 2) then
    zeros.pos := -1;
  // convert to hexa
  p := @s[1];
  tab := @HexCharsLower;
  n := 0;
  repeat
    if n = byte(zeros.pos) then
    begin
      // shorten double zeros to ::
      if n = 0 then
      begin
        p^ := ':';
        inc(p);
      end;
      p^ := ':';
      inc(p);
      ip6addr := @PWordArray(ip6addr)[zeros.len];
      inc(n, zeros.len);
      if n = 8 then
        break;
    end
    else
    begin
      // write up to 4 hexa chars, triming leading 0
      trimlead := true;
      c := ip6addr^[0] shr 4;
      if c <> 0 then
      begin
        p^ := tab[c];
        inc(p);
        trimlead := false;
      end;
      c := ip6addr^[0]; // in two steps for FPC
      c := c and 15;
      if ((c <> 0) and trimlead) or
         not trimlead then
      begin
        p^ := tab[c];
        inc(p);
        trimlead := false;
      end;
      c := ip6addr^[1] shr 4;
      if ((c <> 0) and trimlead) or
         not trimlead then
      begin
        p^ := tab[c];
        inc(p);
      end;
      c := ip6addr^[1];
      c := c and 15; // last hexa char is always there
      p^ := tab[c];
      inc(p);
      inc(PWord(ip6addr));
      inc(n);
      if n = 8 then
        break;
      p^ := ':';
      inc(p);
    end;
  until false;
  p^ := #0; // make null-terminated (won't hurt)
  s[0] := AnsiChar(p - @s[1]);
end;

procedure IP6Text(ip6addr: PByteArray; var result: RawUtf8);
var
  s: ShortString;
begin
  if (PInt64(ip6addr)^ = 0) and
     (PInt64(@ip6addr[7])^ = 0) then // start with 15 zeros?
    case ip6addr[15] of
      0: // IPv6 :: bound to any host -> ''
        begin
          result := '';
          exit;
        end;
      1: // IPv6 ::1 -> '127.0.0.1' loopback (with no memory allocation)
        begin
          result := IP4local;
          exit;
        end;
    end;
  IP6Short(ip6addr, s);
  FastSetString(result, @s[1], ord(s[0]));
end;

function MacToText(mac: PByteArray; maclen: PtrInt): RawUtf8;
var
  P: PAnsiChar;
  i, c: PtrInt;
  tab: PAnsichar;
begin
  FastSetString(result, nil, (maclen * 3) - 1);
  dec(maclen);
  tab := @HexCharsLower;
  P := pointer(result);
  i := 0;
  repeat
    c := mac[i];
    P[0] := tab[c shr 4];
    c := c and 15;
    P[1] := tab[c];
    if i = maclen then
      break;
    P[2] := ':'; // as in Linux
    inc(P, 3);
    inc(i);
  until false;
end;

function MacTextFromHex(const Hex: RawUtf8): RawUtf8;
var
  L: PtrInt;
  h, m: PAnsiChar;
begin
  L := length(Hex);
  if (L = 0) or
     (L and 1 <> 0) then
  begin
    result := '';
    exit;
  end;
  L := L shr 1;
  FastSetString(result, nil, (L * 3) - 1);
  h := pointer(Hex);
  m := pointer(result);
  repeat
    m[0] := h[0];
    if h[0] in ['A'..'Z'] then
      inc(m[0], 32);
    m[1] := h[1];
    if h[1] in ['A'..'Z'] then
      inc(m[1], 32);
    dec(L);
    if L = 0 then
      break;
    m[2] := ':';
    inc(h, 2);
    inc(m, 3);
  until false;
end;

function MacToHex(mac: PByteArray; maclen: PtrInt): RawUtf8;
var
  P: PAnsiChar;
  i, c: PtrInt;
  tab: PAnsichar;
begin
  FastSetString(result, nil, maclen * 2);
  dec(maclen);
  tab := @HexCharsLower;
  P := pointer(result);
  i := 0;
  repeat
    c := mac[i];
    P[0] := tab[c shr 4];
    c := c and 15;
    P[1] := tab[c];
    if i = maclen then
      break;
    inc(P, 2);
    inc(i);
  until false;
end;

var
  // GetIPAddressesText(Sep=' ') cache - refreshed every 32 seconds
  IPAddresses: array[TIPAddress] of record
    Safe: TLightLock;
    Text: RawUtf8;
    Tix: integer;
  end;

  // GetMacAddresses / GetMacAddressesText cache
  MacAddresses: array[{UpAndDown=}boolean] of record
    Safe: TLightLock;
    Searched: boolean; // searched once: no change during process lifetime
    Addresses: TMacAddressDynArray;
    Text: array[{WithoutName=}boolean] of RawUtf8;
  end;

procedure MacIPAddressFlush;
var
  ip: TIPAddress;
begin
  for ip := low(ip) to high(ip) do
   IPAddresses[ip].Tix := 0;
  MacAddresses[false].Text[false] := '';
  MacAddresses[false].Text[true] := '';
  MacAddresses[false].Searched := false;
  MacAddresses[true].Text[false] := '';
  MacAddresses[true].Text[true] := '';
  MacAddresses[true].Searched := false;
end;

function GetIPAddressesText(const Sep: RawUtf8; Kind: TIPAddress): RawUtf8;
var
  ip: TRawUtf8DynArray;
  now: integer;
  i: PtrInt;
begin
  result := '';
  with IPAddresses[Kind] do
  begin
    Safe.Lock;
    try
      if Sep = ' ' then
      begin
        now := mormot.core.os.GetTickCount64 shr 15; // refresh every 32768 ms
        if now <> Tix then
          Tix := now
        else
        begin
          result := Text;
          if result <> '' then
            exit; // return the value from cache
        end;
      end;
      // we need to ask the OS for the current IP addresses
      ip := GetIPAddresses(Kind);
      if ip = nil then
        exit;
      result := ip[0];
      for i := 1 to high(ip) do
        result := result + Sep + ip[i];
      if Sep = ' ' then
        Text := result;
    finally
      Safe.UnLock;
    end;
  end;
end;

function GetMacAddresses(UpAndDown: boolean): TMacAddressDynArray;
begin
  with MacAddresses[UpAndDown] do
  begin
    if not Searched then
    begin
      Safe.Lock;
      try
        if not Searched then
        begin
          Addresses := RetrieveMacAddresses(UpAndDown);
          Searched := true;
        end;
      finally
        Safe.UnLock;
      end;
    end;
    result := Addresses;
  end;
end;

function GetMacAddressesText(WithoutName: boolean; UpAndDown: boolean): RawUtf8;
var
  i: PtrInt;
  addr: TMacAddressDynArray;
  w, wo: RawUtf8;
begin
  with MacAddresses[UpAndDown] do
  begin
    result := Text[WithoutName];
    if (result <> '') or
       Searched then
      exit;
    addr := GetMacAddresses(UpAndDown);
    if addr = nil then
      exit;
    for i := 0 to high(addr) do
      with addr[i] do
      begin
        w := w + Name + '=' + Address + ' ';
        wo := wo + Address + ' ';
      end;
    SetLength(w, length(w) - 1);
    SetLength(wo, length(wo) - 1);
    Safe.Lock; // to avoid memory leak
    Text[false] := w;
    Text[true] := wo;
    Safe.UnLock;
    result := Text[WithoutName];
  end;
end;

function _GetSystemMacAddress: TRawUtf8DynArray;
var
  i, n: PtrInt;
  addr: TMacAddressDynArray;
begin
  addr := GetMacAddresses({UpAndDown=}true);
  SetLength(result, length(addr));
  n := 0;
  for i := 0 to length(addr) - 1 do
    if not NetStartWith(pointer(addr[i].Name), 'DOCKER') then
    begin
      result[n] := addr[i].Address;
      inc(n);
    end;
  SetLength(result, n);
end;


{ ******************** TLS / HTTPS Encryption Abstract Layer }

procedure InitNetTlsContext(var TLS: TNetTlsContext; Server: boolean;
  const CertificateFile, PrivateKeyFile: TFileName;
  const PrivateKeyPassword: RawUtf8; const CACertificatesFile: TFileName);
begin
  FillCharFast(TLS, SizeOf(TLS), 0);
  TLS.IgnoreCertificateErrors := Server; // needed if no mutual auth is done
  TLS.CertificateFile := RawUtf8(CertificateFile);
  TLS.PrivateKeyFile := RawUtf8(PrivateKeyFile);
  TLS.PrivatePassword := PrivateKeyPassword;
  TLS.CACertificatesFile := RawUtf8(CACertificatesFile);
  if Server then
    TLS.OnAcceptServerName := OnNetTlsAcceptServerName; // e.g. mormot.net.acme
end;


{ ******************** Efficient Multiple Sockets Polling }

function ToText(ev: TPollSocketEvents): TShort8;
begin
  result[0] := #0;
  if pseRead in ev then
  begin
    inc(result[0]);
    result[ord(result[0])] := 'r';
  end;
  if pseWrite in ev then
  begin
    inc(result[0]);
    result[ord(result[0])] := 'w';
  end;
  if pseError in ev then
  begin
    inc(result[0]);
    result[ord(result[0])] := 'e';
  end;
  if pseClosed in ev then
  begin
    inc(result[0]);
    result[ord(result[0])] := 'c';
  end;
end;


{ TPollAbstract }

procedure TPollAbstract.Terminate;
begin
end;


{ TPollSocketAbstract }

class function TPollSocketAbstract.FollowEpoll: boolean;
begin
  {$ifdef POLLSOCKETEPOLL}
  result := true; // epoll API is thread-safe and has no size limit
  {$else}
  result := false; // select/poll API are not thread safe
  {$endif POLLSOCKETEPOLL}
end;

constructor TPollSocketAbstract.Create(aOwner: TPollSockets);
begin
  fOwner := aOwner;
end;


{ TPollSockets }

constructor TPollSockets.Create(aPollClass: TPollSocketClass);
begin
  inherited Create;
  if aPollClass = nil then
    fPollClass := PollSocketClass
  else
    fPollClass := aPollClass;
  {$ifdef POLLSOCKETEPOLL}
  // epoll has no size limit (so a single fPoll[0] can be assumed), and
  // epoll_ctl() is thread-safe and let epoll_wait() work in the background
  SetLength(fPoll, 1);
  fPoll[0] := fPollClass.Create(self);
  {$else}
  InitializeCriticalSection(fPollLock);
  {$endif POLLSOCKETEPOLL}
  {$ifdef OSPOSIX}
  SetFileOpenLimit(GetFileOpenLimit(true)); // set soft limit to hard value
  {$endif OSPOSIX}
end;

destructor TPollSockets.Destroy;
var
  i: PtrInt;
  endtix: Int64; // never wait forever
begin
  Terminate;
  if fGettingOne > 0 then
  begin
    if Assigned(fOnLog) then
      fOnLog(sllTrace, 'Destroy: wait for fGettingOne=%', [fGettingOne], self);
    endtix := mormot.core.os.GetTickCount64 + 5000;
    while (fGettingOne > 0) and
          (mormot.core.os.GetTickCount64 < endtix) do
      SleepHiRes(1);
    if Assigned(fOnLog) then
      fOnLog(sllTrace, 'Destroy: ended as fGettingOne=%', [fGettingOne], self);
  end;
  for i := 0 to high(fPoll) do
    FreeAndNilSafe(fPoll[i]);
  {$ifndef POLLSOCKETEPOLL}
  if fUnsubscribeShouldShutdownSocket and
     (fSubscription.UnsubscribeCount > 0) then
  begin
    if Assigned(fOnLog) then
      fOnLog(sllTrace, 'Destroy: shutdown UnsubscribeCount=%',
        [fSubscription.UnsubscribeCount], self);
    for i := 0 to fSubscription.UnsubscribeCount - 1 do
       fSubscription.Unsubscribe[i].ShutdownAndClose({rdwr=}false);
  end;
  DeleteCriticalSection(fPollLock);
  {$endif POLLSOCKETEPOLL}
  inherited Destroy;
end;

function TPollSockets.Subscribe(socket: TNetSocket; events: TPollSocketEvents;
  tag: TPollSocketTag): boolean;
{$ifndef POLLSOCKETEPOLL}
var
  n: PtrInt;
  one: PPollSocketsSubscribe;
{$endif POLLSOCKETEPOLL}
begin
  result := false;
  if (self = nil) or
     (socket = nil) or
     (events = []) then
    exit;
  {$ifdef POLLSOCKETEPOLL}
  // epoll_ctl() is thread-safe and let epoll_wait() work in the background
  result := fPoll[0].Subscribe(socket, events, tag);
  if result then
    LockedInc32(@fCount);
  {$else}
  // fPoll[0].Subscribe() is not allowed when WaitForModified() is running
  // -> trick is to asynch append the information to fSubscription.Subscribe[]
  fSubscriptionSafe.Lock;
  try
    n := fSubscription.SubscribeCount;
    if n = length(fSubscription.Subscribe) then
      SetLength(fSubscription.Subscribe, n + 64);
    one := @fSubscription.Subscribe[n];
    one^.socket := socket;
    one^.tag := tag;
    one^.events := events;
    fSubscription.SubscribeCount := n + 1;
  finally
    fSubscriptionSafe.UnLock;
  end;
  result := true;
  {$endif POLLSOCKETEPOLL}
end;

procedure TPollSockets.Unsubscribe(socket: TNetSocket; tag: TPollSocketTag);
begin
  // actually unsubscribe from the sockets monitoring API
  {$ifdef POLLSOCKETEPOLL}
  // epoll_ctl() is thread-safe and let epoll_wait() work in the background
  if fPoll[0].Unsubscribe(socket) then
  begin
    LockedDec32(@fCount);
    if Assigned(fOnLog) then
      fOnLog(sllTrace, 'Unsubscribe(%) count=%', [pointer(socket), fCount], self);
  end;
  {$else}
  // fPoll[0].UnSubscribe() is not allowed when WaitForModified() is running
  // -> append to the unsubscription asynch list
  fSubscriptionSafe.Lock;
  AddPtrUInt(TPtrUIntDynArray(fSubscription.Unsubscribe),
    fSubscription.UnsubscribeCount, PtrUInt(socket));
  fSubscriptionSafe.UnLock;
  {$endif POLLSOCKETEPOLL}
end;

function FindPendingFromTag(res: PPollSocketResult; n: PtrInt;
  tag: TPollSocketTag): PPollSocketResult;
  {$ifdef HASINLINE} inline; {$endif}
begin
  if n > 0 then
  begin
    result := res;
    repeat
      if result^.tag = tag then // fast O(n) search in L1 cache
        exit;
      inc(result);
      dec(n);
    until n = 0;
  end;
  result := nil;
end;

function TPollSockets.EnsurePending(tag: TPollSocketTag): boolean;
begin
  // manual O(n) brute force search
  result := FindPendingFromTag(
    @fPending.Events[fPendingIndex], fPending.Count - fPendingIndex, tag) <> nil;
end;

procedure TPollSockets.SetPending(tag: TPollSocketTag);
begin
  // overriden method may set a per-connection flag for O(1) lookup
end;

function TPollSockets.UnsetPending(tag: TPollSocketTag): boolean;
begin
  result := true; // overriden e.g. in TPollAsyncReadSockets
end;

function TPollSockets.GetSubscribeCount: integer;
begin
  {$ifdef POLLSOCKETEPOLL}
  result := 0; // epoll_ctl() is called directly
  {$else}
  result := fSubscription.SubscribeCount;
  {$endif POLLSOCKETEPOLL}
end;

function TPollSockets.GetUnsubscribeCount: integer;
begin
  {$ifdef POLLSOCKETEPOLL}
  result := 0;
  {$else}
  result := fSubscription.UnsubscribeCount;
  {$endif POLLSOCKETEPOLL}
end;

function TPollSockets.GetOnePending(out notif: TPollSocketResult;
  const call: RawUtf8): boolean;
var
  n, ndx: PtrInt;
begin
  result := false;
  if fTerminated or
     (fPending.Count <= 0) then
    exit;
  fPendingSafe.Lock;
  {$ifdef HASFASTTRYFINALLY} // make a performance difference
  try                        // and UnsetPending() should be secured
  {$else}
  begin
  {$endif HASFASTTRYFINALLY}
    n := fPending.Count;
    ndx := fPendingIndex;
    if ndx < n then
      repeat
        // retrieve next notified event
        notif := fPending.Events[ndx];
        // move forward
        inc(ndx);
        if (byte(notif.events) <> 0) and  // DeleteOnePending() may reset to 0
           UnsetPending(notif.tag) then   // e.g. TPollAsyncReadSockets
        begin
          // there is a non-void event to return
          result := true;
          fPendingIndex := ndx; // continue with next event
          break;
        end;
      until ndx >= n;
    if ndx >= n then
    begin
      fPending.Count := 0; // reuse shared fPending.Events[] memory
      fPendingIndex := 0;
    end;
  {$ifdef HASFASTTRYFINALLY}
  finally
  {$endif HASFASTTRYFINALLY}
    fPendingSafe.UnLock;
  end;
  if result and
     Assigned(fOnLog) then // log outside fPendingSafe
    fOnLog(sllTrace, 'GetOnePending(%)=% % #%/%', [call, pointer({%H-}notif.tag),
      byte({%H-}notif.events), ndx, n], self);
end;

function TPollSockets.MergePendingEvents(const new: TPollSocketResults): integer;
var
  n, len, cap: PtrInt;
  p: PPollSocketResult;
begin
  len := fPending.Count;
  if len = 0 then
  begin
    // no previous results: just replace the list
    result := new.Count;
    fPending.Count := new.Count;
    fPending.Events := new.Events;
    fPendingIndex := 0;
    if PClass(self)^ <> TPollSockets then // if SetPending() is overriden
    begin
      p := pointer(new.Events);
      n := new.Count;
      repeat
        SetPending(p^.tag); // for O(1) EnsurePending() implementation
        inc(p);
        dec(n);
      until n = 0;
    end;
    exit;
  end;
  // vacuum the results list (to let caller set fPendingIndex := 0)
  if fPendingIndex <> 0 then
  begin
    dec(len, fPendingIndex);
    with fPending do
      MoveFast(Events[fPendingIndex], Events[0], len * SizeOf(Events[0]));
    fPending.Count := len;
    fPendingIndex := 0;
  end;
  result := 0; // returns number of new events to process
  // remove any duplicate: PollForPendingEvents() called before GetOnePending()
  p := pointer(new.Events);
  n := new.Count;
  cap := length(fPending.Events);
  repeat
    if not EnsurePending(p^.Tag) then
    begin
      // new event to process
      if len >= cap then
      begin
        cap := NextGrow(len + new.Count);
        SetLength(fPending.Events, cap); // seldom needed
      end;
      fPending.Events[len] := p^;
      inc(len);
      inc(result);
    end;
    inc(p);
    dec(n);
  until n = 0;
  fPending.Count := len;
end;

function TPollSockets.PollForPendingEvents(timeoutMS: integer): integer;
var
  last, lastcount: PtrInt;
  start, stop: Int64;
  {$ifndef POLLSOCKETEPOLL}
  n, u, s, p: PtrInt;
  poll: TPollSocketAbstract;
  sock: TNetSocket;
  sub: TPollSocketsSubscription;
  {$endif POLLSOCKETEPOLL}
  new: TPollSocketResults; // local list for WaitForModified()
begin
  // by design, this method is called from a single thread
  result := 0;
  if fTerminated then
    exit;
  if Assigned(fOnLog) then
    QueryPerformanceMicroSeconds(start);
  LockedInc32(@fGettingOne);
  try
    // thread-safe get the pending (un)subscriptions
    last := -1;
    new.Count := 0;
    if (fPending.Count = 0) and
       fPendingSafe.TryLock then
    begin
      if fPending.Count = 0 then
      begin
        // reuse the main dynamic array of results
        pointer(new.Events) := pointer(fPending.Events); // inlined MoveAndZero
        pointer(fPending.Events) := nil;
      end;
      fPendingSafe.UnLock;
    end;
    {$ifdef POLLSOCKETEPOLL}
    // epoll_wait() is thread-safe and let epoll_ctl() work in the background
    {if Assigned(OnLog) then
      OnLog(sllTrace, 'PollForPendingEvents: before WaitForModified(%) count=% pending=%',
        [timeoutMS, fCount, fPending.Count], self);}
    if fEpollGettingOne then
      // epoll_wait() is not expected to be used from several threads
      raise ENetSock.Create('%s.PollForPendingEvents should be called from a ' +
        'single thread: please refactor your code', [ClassNameShort(self)^]);
    fEpollGettingOne := true;
    // if fCount=0 epoll_wait() still wait and allow background subscription
    fPoll[0].WaitForModified(new, timeoutMS);
    last := 0;
    lastcount := fPoll[0].Count;
    {$else}
    // manual check of all fPoll[] for subscriptions or modifications
    if fCount + fSubscription.SubscribeCount = 0 then
      exit; // caller would loop
    fSubscriptionSafe.Lock;
    sub.SubscribeCount := fSubscription.SubscribeCount;
    sub.UnsubscribeCount := fSubscription.UnsubscribeCount;
    if (sub.SubscribeCount <> 0) or
       (sub.UnsubscribeCount <> 0) then
      MoveAndZero(@fSubscription, @sub, SizeOf(fSubscription));
    fSubscriptionSafe.UnLock;
    if Assigned(fOnLog) and
       ((sub.SubscribeCount <> 0) or
        (sub.UnsubscribeCount <> 0))then
      fOnLog(sllTrace, 'PollForPendingEvents sub=% unsub=%',
        [sub.SubscribeCount, sub.UnsubscribeCount], self);
    // ensure subscribe + unsubscribe pairs are ignored
    if not fUnsubscribeShouldShutdownSocket then
      for u := 0 to sub.UnsubscribeCount - 1 do
      begin
        sock := sub.Unsubscribe[u];
        for s := 0 to sub.SubscribeCount - 1 do
          if sub.Subscribe[s].socket = sock then
          begin
            if Assigned(fOnLog) then
              fOnLog(sllTrace, 'PollForPendingEvents sub+unsub sock=%',
                [pointer(sock)], self);
            sub.Unsubscribe[u] := nil; // mark both no op
            sub.Subscribe[s].socket := nil;
            break;
          end;
      end;
    // use fPoll[] to retrieve any pending notifications
    mormot.core.os.EnterCriticalSection(fPollLock);
    try
      // first unsubscribe closed connections
      for u := 0 to sub.UnsubscribeCount - 1 do
      begin
        sock := sub.Unsubscribe[u];
        if sock <> nil then
          for p := 0 to length(fPoll) - 1 do
            if fPoll[p].Unsubscribe(sock) then
            begin
              dec(fCount);
              if fUnsubscribeShouldShutdownSocket then
                sock.ShutdownAndClose({rdwr=}false);
              {if Assigned(fOnLog) then
                fOnLog(sllTrace, 'PollForPendingEvents Unsubscribe(%) count=%',
                  [pointer(sock), fCount], self);}
              sock := nil;
              break;
            end;
        if sock <> nil then
          if Assigned(fOnLog) then
            fOnLog(sllTrace, 'PollForPendingEvents Unsubscribe(%) failed count=%',
              [pointer(sock), fCount], self);
      end;
      // then subscribe to the new connections
      for s := 0 to sub.SubscribeCount - 1 do
        if sub.Subscribe[s].socket <> nil then
        begin
          poll := nil;
          n := length(fPoll);
          for p := 0 to n - 1 do
            if fPoll[p].Count < fPoll[p].MaxSockets then
            begin
              poll := fPoll[p]; // stil some place in this poll instance
              break;
            end;
          if poll = nil then
          begin
            poll := fPollClass.Create(self); // need a new poll instance
            SetLength(fPoll, n + 1);
            fPoll[n] := poll;
          end;
          if Assigned(fOnLog) then
            fOnLog(sllTrace, 'PollForPendingEvents Subscribe(%) count=%',
              [pointer(sub.Subscribe[s].socket), fCount], self);
          with sub.Subscribe[s] do
            if poll.Subscribe(socket, events, tag) then
              inc(fCount)
            else if Assigned(fOnLog) then
              fOnLog(sllTrace, 'PollForPendingEvents Subscribe(%) failed count=%',
                [pointer(socket), fCount], self);
        end;
      // eventually do the actual polling
      if fTerminated or
         (fCount = 0) then
        exit; // nothing to track any more (all Unsubscribe)
      n := length(fPoll);
      if n = 0 then
        exit;
      if timeoutMS > 0 then
      begin
        timeoutMS := timeoutMS div n;
        if timeoutMS = 0 then
          timeoutMS := 1;
      end;
      // calls fPoll[].WaitForModified() to refresh pending state
      for p := fPollIndex + 1 to n - 1 do
        // search from fPollIndex = last found
        if fTerminated then
          exit
        else if fPoll[p].WaitForModified(new, timeoutMS) then
        begin
          last := p;
          break;
        end;
      if last < 0 then
        for p := 0 to fPollIndex do
          // search from beginning up to fPollIndex
          if fTerminated then
            exit
          else if fPoll[p].WaitForModified(new, timeoutMS) then
          begin
            last := p;
            break;
          end;
      if last < 0 then
        exit;
      // WaitForModified() did return some events in new local list
      fPollIndex := last; // next call will continue from fPoll[fPollIndex+1]
      lastcount := fPoll[last].Count;
    finally
      mormot.core.os.LeaveCriticalSection(fPollLock);
    end;
    {$endif POLLSOCKETEPOLL}
    // append the new events to the main fPending list
    result := new.Count;
    if (result <= 0) or
       fTerminated then
      exit;
    fPendingSafe.Lock;
    try
      result := MergePendingEvents(new);
    finally
      fPendingSafe.UnLock;
    end;
    new.Events := nil;
    if (result > 0) and
       Assigned(fOnLog) then
    begin
      QueryPerformanceMicroSeconds(stop);
      fOnLog(sllTrace,
        'PollForPendingEvents=% in fPoll[%] (subscribed=%) pending=% %us',
          [result, last, lastcount, fPending.Count, stop - start], self);
    end;
  finally
    LockedDec32(@fGettingOne);
    {$ifdef POLLSOCKETEPOLL}
    fEpollGettingOne := false;
    {$endif POLLSOCKETEPOLL}
  end;
end;

procedure TPollSockets.AddOnePending(
  aTag: TPollSocketTag; aEvents: TPollSocketEvents; aSearchExisting: boolean);
var
  n: PtrInt;
begin
  fPendingSafe.Lock;
  try
    n := fPending.Count;
    if (n = 0) or
       (not aSearchExisting) or
       (not EnsurePending(aTag)) then
    begin
      if n >= length(fPending.Events) then
        SetLength(fPending.Events, NextGrow(n));
      with fPending.Events[n] do
      begin
        tag := aTag;
        events := aEvents;
      end;
      fPending.Count := n + 1;
    end;
  finally
    fPendingSafe.UnLock;
  end;
end;

function TPollSockets.DeleteOnePending(aTag: TPollSocketTag): boolean;
var
  fnd: PPollSocketResult;
begin
  result := false;
  if (fPending.Count = 0) or
     (aTag = 0) then
    exit;
  fPendingSafe.Lock;
  try
    if fPending.Count <> 0 then
    begin
      fnd := FindPendingFromTag( // fast O(n) search in L1 cache
        @fPending.Events[fPendingIndex], fPending.Count - fPendingIndex, aTag);
      if fnd <> nil then
      begin
        byte(fnd^.events) := 0; // GetOnePending() will just ignore it
        result := true;
      end;
    end;
  finally
    fPendingSafe.UnLock;
  end;
end;

function TPollSockets.DeleteSeveralPending(
  aTag: PPollSocketTag; aTagCount: integer): integer;
var
  p: PPollSocketResult;
  n: integer;
begin
  result := 0;
  if (fPending.Count = 0) or
     (aTagCount = 0) then
    exit;
  dec(aTagCount);
  if aTagCount = 0 then
  begin
    result := ord(DeleteOnePending(aTag^));
    exit;
  end;
  QuickSortPtrInt(pointer(aTag), 0, aTagCount);
  fPendingSafe.Lock;
  try
    n := fPending.Count;
    if n = 0 then
      exit;
    dec(n, fPendingIndex);
    p := @fPending.Events[fPendingIndex];
    if n > 0 then
      repeat
        if FastFindPtrIntSorted(pointer(aTag), aTagCount, p^.tag) >= 0 then
        begin
          byte(p^.events) := 0; // GetOnePending() will just ignore it
          inc(result);
        end;
        inc(p);
        dec(n)
      until n = 0;
  finally
    fPendingSafe.UnLock;
  end;
end;

function TPollSockets.GetOne(timeoutMS: integer; const call: RawUtf8;
  out notif: TPollSocketResult): boolean;
{$ifndef POLLSOCKETEPOLL}
var
  start, tix, endtix: Int64;
{$endif POLLSOCKETEPOLL}
begin
  // first check if some pending events are available
  result := GetOnePending(notif, call);
  if result or
     fTerminated or
     (timeoutMS < 0) then
    exit;
  // here we need to ask the socket layer
  {$ifdef POLLSOCKETEPOLL}
  // epoll_wait() is thread-safe and let epoll_ctl() work in the background
  PollForPendingEvents(timeoutMS); // inc(fGettingOne) +  blocking epoll_wait
  result := GetOnePending(notif, call);
  if Assigned(fOnGetOneIdle) then
    fOnGetOneIdle(self, mormot.core.os.GetTickCount64);
  {$else}
  // non-blocking call of PollForPendingEvents()
  byte(notif.events) := 0;
  start := 0;
  endtix := 0;
  LockedInc32(@fGettingOne);
  try
    repeat
      // non-blocking search of pending events within all subscribed fPoll[]
      if fTerminated then
        exit;
      if fPending.Count = 0 then
        PollForPendingEvents({timeoutMS=}10);
      if fTerminated then
        exit;
      if GetOnePending(notif, call) then
      begin
        result := true;
        exit;
      end;
      // if we reached here, we have no pending event
      if fTerminated or
         (timeoutMS = 0) then
        exit;
      // wait a little for something to happen
      tix := SleepStep(start, @fTerminated); // 0/1/5/50/120-250 ms steps
      if endtix = 0 then
        endtix := start + timeoutMS
      else if Assigned(fOnGetOneIdle) then
        fOnGetOneIdle(self, tix);
      if fTerminated then
        exit;
      result := GetOnePending(notif, call); // retrieved from another thread?
    until result or
          (tix > endtix);
  finally
    LockedDec32(@fGettingOne);
  end;
  {$endif POLLSOCKETEPOLL}
end;

procedure TPollSockets.Terminate;
var
  i: PtrInt;
begin
  if self = nil then
    exit;
  fTerminated := true;
  for i := 0 to high(fPoll) do
    fPoll[i].Terminate;
end;


{ *************************** TUri parsing/generating URL wrapper }

function NetStartWith(p, up: PUtf8Char): boolean;
// to avoid linking mormot.core.text for IdemPChar()
var
  c, u: AnsiChar;
begin
  result := false;
  if (p = nil) or
     (up = nil) then
    exit;
  repeat
    u := up^;
    if u = #0 then
      break;
    inc(up);
    c := p^;
    inc(p);
    if c = u  then
      continue;
    if (c >= 'a') and
       (c <= 'z') then
    begin
      dec(c, 32);
      if c <> u then
        exit;
    end
    else
      exit;
  until false;
  result := true;
end;

procedure DoEncode(rp, sp: PAnsiChar; len: cardinal);
const
  b64: array[0..63] of AnsiChar =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  i, c: cardinal;
begin
  for i := 1 to len div 3 do
  begin
    c := ord(sp[0]) shl 16 + ord(sp[1]) shl 8 + ord(sp[2]);
    rp[0] := b64[(c shr 18) and $3f];
    rp[1] := b64[(c shr 12) and $3f];
    rp[2] := b64[(c shr 6) and $3f];
    rp[3] := b64[c and $3f];
    inc(rp, 4);
    inc(sp, 3);
  end;
  case len mod 3 of
    1:
      begin
        c := ord(sp[0]) shl 16;
        rp[0] := b64[(c shr 18) and $3f];
        rp[1] := b64[(c shr 12) and $3f];
        rp[2] := '=';
        rp[3] := '=';
      end;
    2:
      begin
        c := ord(sp[0]) shl 16 + ord(sp[1]) shl 8;
        rp[0] := b64[(c shr 18) and $3f];
        rp[1] := b64[(c shr 12) and $3f];
        rp[2] := b64[(c shr 6) and $3f];
        rp[3] := '=';
      end;
  end;
end;

function SockBase64Encode(const s: RawUtf8): RawUtf8;
// to avoid linking mormot.core.buffers for BinToBase64()
var
  len: cardinal;
begin
  result:='';
  len := length(s);
  if len = 0 then
    exit;
  SetLength(result, ((len + 2) div 3) * 4);
  DoEncode(pointer(result), pointer(s), len);
end;

function SplitFromRight(const Text: RawUtf8; Sep: AnsiChar;
  var Before, After: RawUtf8): boolean;
var
  i: PtrInt;
begin
  for i := length(Text) - 1 downto 2 do // search Sep from right side
    if Text[i] = Sep then
    begin
      TrimCopy(Text, 1, i - 1, Before);
      TrimCopy(Text, i + 1, maxInt, After);
      result := true;
      exit;
    end;
  result := false;
end;


{ TUri }

procedure TUri.Clear;
begin
  Https := false;
  layer := nlTcp;
  Finalize(self);
end;

function TUri.From(aUri: RawUtf8; const DefaultPort: RawUtf8): boolean;
var
  P, S, P1, P2: PAnsiChar;
  i: integer;
begin
  Clear;
  result := false;
  TrimSelf(aUri);
  if aUri = '' then
    exit;
  P := pointer(aUri);
  S := P;
  while S^ in ['a'..'z', 'A'..'Z', '+', '-', '.', '0'..'9'] do
    inc(S);
  if PInteger(S)^ and $ffffff = ord(':') + ord('/') shl 8 + ord('/') shl 16 then
  begin
    FastSetString(Scheme, P, S - P);
    if NetStartWith(pointer(P), 'HTTPS') then
      Https := true
    else if NetStartWith(pointer(P), 'UDP') then
      layer := nlUdp; // 'udp://server:port';
    P := S + 3;
  end;
  if NetStartWith(pointer(P), 'UNIX:') then
  begin
    inc(P, 5); // 'http://unix:/path/to/socket.sock:/url/path'
    layer := nlUnix;
    S := P;
    while not (S^ in [#0, ':']) do
      inc(S); // Server='path/to/socket.sock'
  end
  else
  begin
    P1 := pointer(PosChar(pointer(P), '@'));
    if P1 <> nil then
    begin
      // parse 'https://user:password@server:port/address'
      P2 := pointer(PosChar(pointer(P), '/'));
      if (P2 = nil) or
         (PtrUInt(P2) > PtrUInt(P1)) then
      begin
        FastSetString(User, P, P1 - P);
        i := PosExChar(':', User);
        if i <> 0 then
        begin
          Password := copy(User, i + 1, 1000);
          SetLength(User, i - 1);
        end;
        P := P1 + 1;
      end;
    end;
    S := P;
    while not (S^ in [#0, ':', '/']) do
      inc(S); // 'server:port/address' or 'server/address'
  end;
  FastSetString(Server, P, S - P);
  if S^ = ':' then
  begin
    inc(S);
    P := S;
    while not (S^ in [#0, '/']) do
      inc(S);
    FastSetString(Port, P, S - P); // Port='' for nlUnix
  end
  else if DefaultPort <> '' then
    port := DefaultPort
  else
    port := DEFAULT_PORT[Https];
  if S^ <> #0 then // ':' or '/'
  begin
    inc(S);
    FastSetString(Address, S, StrLen(S));
  end;
  if Server <> '' then
    result := true;
end;

function TUri.URI: RawUtf8;
const
  Prefix: array[boolean] of RawUtf8 = (
    'http://', 'https://');
begin
  if layer = nlUnix then
    result := 'http://unix:' + Server + ':/' + address
  else if (port = '') or
          (port = '0') or
          (port = DEFAULT_PORT[Https]) then
    result := Prefix[Https] + Server + '/' + address
  else
    result := Prefix[Https] + Server + ':' + port + '/' + address;
end;

function TUri.PortInt: TNetPort;
begin
  result := GetCardinal(pointer(port));
end;

function TUri.Root: RawUtf8;
var
  i: PtrInt;
begin
  i := PosExChar('?', address);
  if i = 0 then
    Root := address
  else
    Root := copy(address, 1, i - 1);
end;

function TUri.UserPasswordBase64: RawUtf8;
begin
  if User = '' then
    result := ''
  else
    result := SockBase64Encode(User + ':' + Password);
end;


{ ********* TCrtSocket Buffered Socket Read/Write Class }

{ TCrtSocket }

function TCrtSocket.GetRawSocket: PtrInt;
begin
  result := PtrInt(fSock);
end;

procedure TCrtSocket.SetKeepAlive(aKeepAlive: boolean);
begin
  fSock.SetKeepAlive(aKeepAlive);
end;

procedure TCrtSocket.SetLinger(aLinger: integer);
begin
  fSock.SetLinger(aLinger);
end;

procedure TCrtSocket.SetReceiveTimeout(aReceiveTimeout: integer);
begin
  fSock.SetReceiveTimeout(aReceiveTimeout);
end;

procedure TCrtSocket.SetSendTimeout(aSendTimeout: integer);
begin
  fSock.SetSendTimeout(aSendTimeout);
end;

procedure TCrtSocket.SetTcpNoDelay(aTcpNoDelay: boolean);
begin
  fSock.SetNoDelay(aTcpNoDelay);
end;

constructor TCrtSocket.Create(aTimeOut: PtrInt);
begin
  fTimeOut := aTimeOut;
end;

constructor TCrtSocket.Open(const aServer, aPort: RawUtf8;
  aLayer: TNetLayer; aTimeOut: cardinal; aTLS: boolean;
  aTLSContext: PNetTlsContext; aTunnel: PUri);
begin
  Create(aTimeOut); // default read timeout is 10 seconds
  // copy the input parameters before OpenBind()
  if aTLSContext <> nil then
    TLS := aTLSContext^;
  if (aTunnel <> nil) and
     (aTunnel^.Server <> '') then
    Tunnel := aTunnel^;
  // OpenBind() raise an exception on error
  {$ifdef OSPOSIX}
  if NetStartWith(pointer(aServer), 'UNIX:') then
  begin
    // aServer='unix:/path/to/myapp.socket'
    OpenBind(copy(aServer, 6, 200), '', {dobind=}false, aTLS, nlUnix);
    fServer := aServer; // keep the full server name if reused after Close
  end
  else
  {$endif OSPOSIX}
    OpenBind(aServer, aPort, {dobind=}false, aTLS, aLayer);
  if aTLSContext <> nil then
    aTLSContext^ := TLS; // copy back information to the caller TNetTlsContext
end;

constructor TCrtSocket.OpenUri(const aUri: RawUtf8; out aAddress: RawUtf8;
  const aTunnel: RawUtf8; aTimeOut: cardinal; aTLSContext: PNetTlsContext);
var
  u, t: TUri;
begin
  if not u.From(aUri) then
    raise ENetSock.Create('%s.OpenUri: invalid %s', [ClassNameShort(self)^, aUri]);
  aAddress := u.Address;
  t.From(aTunnel);
  Open(u.Server, u.Port, nlTcp, aTimeOut, u.Https, aTLSContext, @t);
end;

const
  BINDTXT: array[boolean] of string[4] = (
    'open', 'bind');
  BINDMSG: array[boolean] of string = (
    'Is a server available on this address:port?',
    'Another process may be currently listening to this port!');

constructor TCrtSocket.Bind(const aAddress: RawUtf8; aLayer: TNetLayer;
  aTimeOut: integer);
var
  s, p: RawUtf8;
  aSock: integer;
begin
  Create(aTimeOut);
  if aAddress = '' then
  begin
    {$ifdef OSLINUX} // try systemd activation
    if not sd.IsAvailable then
      raise ENetSock.Create('%s.Bind('''') but Systemd is not available',
        [ClassNameShort(self)^]);
    if sd.listen_fds(0) > 1 then
      raise ENetSock.Create('%s.Bind(''''): Systemd activation failed - too ' +
        'many file descriptors received', [ClassNameShort(self)^]);
    aSock := SD_LISTEN_FDS_START + 0;
    {$else}
    raise ENetSock.Create('%s.Bind(''''), i.e. Systemd activation, ' +
      'is not allowed on this platform', [ClassNameShort(self)^]);
    {$endif OSLINUX}
  end
  else
  begin
    aSock := -1; // force OpenBind to create listening socket
    if not SplitFromRight(aAddress, ':', s, p) then
    begin
      s := '0.0.0.0';
      p := aAddress;
    end;
    {$ifdef OSPOSIX}
    if s = 'unix' then
    begin
      // aAddress='unix:/path/to/myapp.socket'
      FpUnlink(pointer(p)); // previous bind may have left the .socket file
      OpenBind(p, '', {dobind=}true, {tls=}false, nlUnix, {%H-}TNetSocket(aSock));
      exit;
    end;
    {$endif OSPOSIX}
  end;
  // next line will raise exception on error
  OpenBind(s{%H-}, p{%H-}, {dobind=}true, {tls=}false, aLayer, {%H-}TNetSocket(aSock));
  {$ifdef OSLINUX}
  // in case started by systemd (port=''), listening socket is created by
  // another process and do not interrupt when it got a signal. So we need to
  // set a timeout to unlock accept() periodically and check for termination
  if aAddress = '' then     // external socket
    ReceiveTimeout := 1000; // unblock accept every second
  {$endif OSLINUX}
end;

procedure TCrtSocket.DoTlsAfter(caller: TCrtSocketTlsAfter);
begin
  if fSecure = nil then // ignore duplicated calls
  try
    if not Assigned(NewNetTls) then
      raise ENetSock.Create('%s.DoTlsAfter: TLS support not compiled ' +
        '- try including mormot.lib.openssl11 in your project',
        [ClassNameShort(self)^]);
    fSecure := NewNetTls;
    if fSecure = nil then
      raise ENetSock.Create('%s.DoTlsAfter: TLS is not available on this ' +
        'system - try installing OpenSSL 1.1.1/3.x', [ClassNameShort(self)^]);
    case caller of
      cstaConnect:
        fSecure.AfterConnection(fSock, TLS, fServer);
      cstaBind:
        fSecure.AfterBind(TLS);
      cstaAccept:
        fSecure.AfterAccept(fSock, TLS, @TLS.LastError, @TLS.CipherName)
    end;
    TLS.Enabled := true; // set the flag AFTER fSecure has been initialized
  except
    on E: Exception do
    begin
      fSecure := nil;
      raise ENetSock.CreateFmt('%s.DoTlsAfter: TLS failed [%s %s]',
        [ClassNameShort(self)^, ClassNameShort(E)^, E.Message]);
    end;
  end;
end;

procedure TCrtSocket.OpenBind(const aServer, aPort: RawUtf8; doBind: boolean;
  aTLS: boolean; aLayer: TNetLayer; aSock: TNetSocket);
var
  retry: integer;
  head: RawUtf8;
  res: TNetResult;
begin
  TLS.Enabled := false; // reset this flag which is set at output if aTLS=true
  fSocketLayer := aLayer;
  fWasBind := doBind;
  if {%H-}PtrInt(aSock)<=0 then
  begin
    // OPEN or BIND mode -> create the socket
    fServer := aServer;
    if (aPort = '') and
       (aLayer <> nlUnix) then
      fPort := DEFAULT_PORT[aTLS] // default port is 80/443 (HTTP/S)
    else
      fPort := aPort;
    if doBind then
      // allow small number of retries (e.g. XP or BSD during aggressive tests)
      retry := 10
    else if (Tunnel.Server <> '') and
            (Tunnel.Server <> fServer) and
            (aLayer = nlTcp) then
    begin
      // handle client tunnelling via an HTTP(s) proxy
      fProxyUrl := Tunnel.URI;
      if Tunnel.Https and aTLS then
        raise ENetSock.Create('%s.Open(%s:%s): %s proxy - unsupported dual ' +
          'TLS layers', [ClassNameShort(self)^, fServer, fPort, fProxyUrl]);
      try
        res := NewSocket(Tunnel.Server, Tunnel.Port, nlTcp, {doBind=}false,
          fTimeout, fTimeout, fTimeout, {retry=}2, fSock);
        if res = nrOK then
        begin
          res := nrRefused;
          SockSend(['CONNECT ', fServer, ':', fPort, ' HTTP/1.0']);
          if Tunnel.User <> '' then
            SockSend(['Proxy-Authorization: Basic ', Tunnel.UserPasswordBase64]);
          SockSendFlush(#13#10);
          repeat
            SockRecvLn(head);
            if NetStartWith(pointer(head), 'HTTP/') and
               (length(head) > 11) and
               (head[10] = '2') then // 'HTTP/1.1 2xx xxxx' success
              res := nrOK;
          until head = '';
        end;
      except
        on E: Exception do
          raise ENetSock.Create('%s.Open(%s:%s): %s proxy error %s',
            [ClassNameShort(self)^, fServer, fPort, fProxyUrl, E.Message]);
      end;
      if res <> nrOk then
        raise ENetSock.Create('%s.Open(%s:%s): %s proxy error',
          [ClassNameShort(self)^, fServer, fPort, fProxyUrl], res);
      if Assigned(OnLog) then
        OnLog(sllTrace, 'Open(%:%) via proxy %', [fServer, fPort, fProxyUrl], self);
      if aTLS then
        DoTlsAfter(cstaConnect);
      exit;
    end
    else
      // direct client connection
      retry := {$ifdef OSBSD} 10 {$else} 2 {$endif};
    //if Assigned(OnLog) then
    //  OnLog(sllTrace, 'Before NewSocket', [], self);
    res := NewSocket(fServer, fPort, aLayer, doBind,
      fTimeout, fTimeout, fTimeout, retry, fSock);
    //if Assigned(OnLog) then
    //  OnLog(sllTrace, 'After NewSocket=%', [ToText(res)^], self);
    if res <> nrOK then
      raise ENetSock.Create('%s %s.OpenBind(%s:%s)',
        [BINDMSG[doBind], ClassNameShort(self)^, fServer, fPort], res);
  end
  else
  begin
    // ACCEPT mode -> socket is already created by caller
    fSock := aSock;
    if TimeOut > 0 then
    begin
      // set timout values for both directions
      ReceiveTimeout := TimeOut;
      SendTimeout := TimeOut;
    end;
  end;
  if (aLayer = nlTcp) and
     aTLS then
    if doBind then
      DoTlsAfter(cstaBind) // never called by OpenBind(aTLS=false) in practice
    else if {%H-}PtrInt(aSock) <= 0 then
      DoTlsAfter(cstaConnect);
  if Assigned(OnLog) then
    OnLog(sllTrace, '%(%:%) sock=% %', [BINDTXT[doBind], fServer, fPort,
      pointer(fSock.Socket), TLS.CipherName], self);
end;

procedure TCrtSocket.AcceptRequest(aClientSock: TNetSocket; aClientAddr: PNetAddr);
begin
  {$ifdef OSLINUX}
  // on Linux fd returned from accept() inherits all parent fd options
  // except O_NONBLOCK and O_ASYNC
  fSock := aClientSock;
  {$else}
  // on other OS inheritance is undefined, so call OpenBind to set all fd options
  OpenBind('', '', {bind=}false, {tls=}false, fSocketLayer, aClientSock);
  // assign the ACCEPTed aClientSock to this TCrtSocket instance
  Linger := 5; // should remain open for 5 seconds after a closesocket() call
  {$endif OSLINUX}
  if aClientAddr <> nil then
    aClientAddr^.IP(fRemoteIP, RemoteIPLocalHostAsVoidInServers);
  {$ifdef OSLINUX}
  if Assigned(OnLog) then
    OnLog(sllTrace, 'Accept(%:%) sock=% %',
      [fServer, fPort, fSock.Socket, fRemoteIP], self);
  {$endif OSLINUX}
end;

const
  SOCKMINBUFSIZE = 1024; // big enough for headers (content will be read directly)

type
  PTextRec = ^TTextRec;
  PCrtSocket = ^TCrtSocket;

function OutputSock(var F: TTextRec): integer;
begin
  if F.BufPos = 0 then
    result := NO_ERROR
  else if PCrtSocket(@F.UserData)^.TrySndLow(F.BufPtr, F.BufPos) then
  begin
    F.BufPos := 0;
    result := NO_ERROR;
  end
  else
    result := -1; // on socket error -> raise ioresult error
end;

function InputSock(var F: TTextRec): integer;
// SockIn pseudo text file fill its internal buffer only with available data
// -> no unwanted wait time is added
// -> very optimized use for readln() in HTTP stream
var
  size: integer;
  sock: TCrtSocket;
begin
  F.BufEnd := 0;
  F.BufPos := 0;
  sock := PCrtSocket(@F.UserData)^;
  if not sock.SockIsDefined then
  begin
    result := WSAECONNABORTED; // on socket error -> raise ioresult error
    exit; // file closed = no socket -> error
  end;
  result := sock.fSockInEofError;
  if result <> 0 then
    exit; // already reached error below
  size := F.BufSize;
  if sock.SocketLayer = nlUdp then
  begin
    if sock.fPeerAddr = nil then
      New(sock.fPeerAddr); // allocated on demand (may be up to 110 bytes)
    size := sock.Sock.RecvFrom(F.BufPtr, size, sock.fPeerAddr^);
  end
  else
    // nlTcp/nlUnix
    if not sock.TrySockRecv(F.BufPtr, size, {StopBeforeLength=}true) then
      size := -1; // fatal socket error
  // TrySockRecv() may return size=0 if no data is pending, but no TCP/IP error
  if size >= 0 then
  begin
    F.BufEnd := size;
    inc(sock.fBytesIn, size);
    result := NO_ERROR;
  end
  else
  begin
    if not sock.SockIsDefined then // socket broken or closed
      result := WSAECONNABORTED
    else
    begin
      result := -sockerrno; // ioresult = low-level socket error as negative
      if result = 0 then
        result := WSAETIMEDOUT;
    end;
    sock.fSockInEofError := result; // error -> mark end of SockIn
    // result <0 will update ioresult and raise an exception if {$I+}
  end;
end;

function CloseSock(var F: TTextRec): integer;
begin
  if PCrtSocket(@F.UserData)^ <> nil then
    PCrtSocket(@F.UserData)^.Close;
  PCrtSocket(@F.UserData)^ := nil;
  result := NO_ERROR;
end;

function OpenSock(var F: TTextRec): integer;
begin
  F.BufPos := 0;
  F.BufEnd := 0;
  if F.Mode = fmInput then
  begin
    // ReadLn
    F.InOutFunc := @InputSock;
    F.FlushFunc := nil;
  end
  else
  begin
    // WriteLn
    F.Mode := fmOutput;
    F.InOutFunc := @OutputSock;
    F.FlushFunc := @OutputSock;
  end;
  F.CloseFunc := @CloseSock;
  result := NO_ERROR;
end;

{$ifdef FPC}
procedure SetLineBreakStyle(var T: Text; Style: TTextLineBreakStyle);
begin
  case Style of
    tlbsCR:
      TextRec(T).LineEnd := #13;
    tlbsLF:
      TextRec(T).LineEnd := #10;
    tlbsCRLF:
      TextRec(T).LineEnd := #13#10;
  end;
end;
{$endif FPC}

procedure TCrtSocket.CreateSockIn(LineBreak: TTextLineBreakStyle;
  InputBufferSize: integer);
begin
  if (Self = nil) or
     (SockIn <> nil) then
    exit; // initialization already occured
  if InputBufferSize < SOCKMINBUFSIZE then
    InputBufferSize := SOCKMINBUFSIZE;
  GetMem(fSockIn, SizeOf(TTextRec) + InputBufferSize);
  FillCharFast(SockIn^, SizeOf(TTextRec), 0);
  with TTextRec(SockIn^) do
  begin
    PCrtSocket(@UserData)^ := self;
    Mode := fmClosed;
    // ignore internal Buffer[], which is not trailing on latest Delphi and FPC
    BufSize := InputBufferSize;
    BufPtr := pointer(PAnsiChar(SockIn) + SizeOf(TTextRec));
    OpenFunc := @OpenSock;
    Handle := {$ifdef FPC}THandle{$endif}(-1);
  end;
  SetLineBreakStyle(SockIn^, LineBreak); // http does break lines with #13#10
  Reset(SockIn^);
end;

procedure TCrtSocket.CreateSockOut(OutputBufferSize: integer);
begin
  if SockOut <> nil then
    exit; // initialization already occured
  if OutputBufferSize < SOCKMINBUFSIZE then
    OutputBufferSize := SOCKMINBUFSIZE;
  GetMem(fSockOut, SizeOf(TTextRec) + OutputBufferSize);
  FillCharFast(SockOut^, SizeOf(TTextRec), 0);
  with TTextRec(SockOut^) do
  begin
    PCrtSocket(@UserData)^ := self;
    Mode := fmClosed;
    BufSize := OutputBufferSize;
    BufPtr := pointer(PAnsiChar(SockIn) + SizeOf(TTextRec)); // ignore Buffer[] (Delphi 2009+)
    OpenFunc := @OpenSock;
    Handle := {$ifdef FPC}THandle{$endif}(-1);
  end;
  SetLineBreakStyle(SockOut^, tlbsCRLF); // force e.g. for Linux platforms
  Rewrite(SockOut^);
end;

procedure TCrtSocket.CloseSockIn;
begin
  if (self <> nil) and
     (fSockIn <> nil) then
  begin
    Freemem(fSockIn);
    fSockIn := nil;
  end;
end;

procedure TCrtSocket.CloseSockOut;
begin
  if (self <> nil) and
     (fSockOut <> nil) then
  begin
    Freemem(fSockOut);
    fSockOut := nil;
  end;
end;

{ $define SYNCRTDEBUGLOW2}

procedure TCrtSocket.Close;
// notice: sequential Close + OpenBind sets should work with the same instance
{$ifdef SYNCRTDEBUGLOW2}
var // closesocket() or shutdown() are slow e.g. on Windows with wrong Linger
  start, stop: int64;
{$endif SYNCRTDEBUGLOW2}
begin
  // reset internal state
  fSndBufLen := 0; // always reset (e.g. in case of further Open)
  fSockInEofError := 0;
  ioresult; // reset readln/writeln value
  if SockIn <> nil then
  begin
    PTextRec(SockIn)^.BufPos := 0;  // reset input buffer, but keep allocated
    PTextRec(SockIn)^.BufEnd := 0;
  end;
  if SockOut <> nil then
  begin
    PTextRec(SockOut)^.BufPos := 0; // reset output buffer
    PTextRec(SockOut)^.BufEnd := 0;
  end;
  if not SockIsDefined then
    exit; // no opened connection, or Close already executed
  // perform the TLS shutdown round and release the TLS context
  fSecure := nil; // will depend on the actual implementation class
  // don't reset TLS.Enabled := false because it is needed e.g. on re-connect
  // actually close the socket and mark it as not SockIsDefined (<0)
  {$ifdef SYNCRTDEBUGLOW2}
  QueryPerformanceMicroSeconds(start);
  {$endif SYNCRTDEBUGLOW2}
  {$ifdef OSLINUX}
  if not fWasBind or
     (fPort <> '') then // no explicit shutdown necessary on Linux server side
  {$endif OSLINUX}
    fSock.ShutdownAndClose({rdwr=}fWasBind);
  {$ifdef SYNCRTDEBUGLOW2}
  QueryPerformanceMicroSeconds(stop);
  TSynLog.Add.Log(sllTrace, 'ShutdownAndClose(%): %', [fWasBind, stop-start], self);
  {$endif SYNCRTDEBUGLOW2}
  fSock := TNetSocket(-1);
  // don't reset fServer/fPort/fTls/fWasBind: caller may use them to reconnect
  // (see e.g. THttpClientSocket.Request)
  {$ifdef OSPOSIX}
  if fSocketLayer = nlUnix then
    FpUnlink(pointer(fServer)); // 'unix:/path/to/myapp.socket' -> delete file
  {$endif OSPOSIX}
end;

destructor TCrtSocket.Destroy;
begin
  Close;
  CloseSockIn;
  CloseSockOut;
  if fPeerAddr <> nil then
    Dispose(fPeerAddr);
  inherited Destroy;
end;

function TCrtSocket.SockInRead(Content: PAnsiChar; Length: integer;
  UseOnlySockIn: boolean): integer;
var
  len, res: integer;
// read Length bytes from SockIn^ buffer + Sock if necessary
begin
  // get data from SockIn buffer, if any (faster than ReadChar)
  result := 0;
  if Length <= 0 then
    exit;
  if SockIn <> nil then
    with PTextRec(SockIn)^ do
      repeat
        len := BufEnd - BufPos;
        if len > 0 then
        begin
          if len > Length then
            len := Length;
          MoveFast(BufPtr[BufPos], Content^, len);
          inc(BufPos, len);
          inc(Content, len);
          dec(Length, len);
          inc(result, len);
        end;
        if Length = 0 then
          exit; // we got everything we wanted
        if not UseOnlySockIn then
          break;
        res := InputSock(PTextRec(SockIn)^);
        if res < 0 then
          ENetSock.CheckLastError('SockInRead', {forceraise=}true);
        // loop until Timeout
      until Timeout = 0;
  // direct receiving of the remaining bytes from socket
  if Length > 0 then
  begin
    SockRecv(Content, Length); // raise ENetSock if failed to read Length
    inc(result, Length);
  end;
end;

function TCrtSocket.SockIsDefined: boolean;
begin
  result := (self <> nil) and
            ({%H-}PtrInt(fSock) > 0);
end;

function TCrtSocket.SockInPending(aTimeOutMS: integer;
  aPendingAlsoInSocket: boolean): integer;
var
  backup: PtrInt;
  {$ifdef OSWINDOWS}
  insocket: integer;
  {$endif OSWINDOWS}
begin
  if SockIn = nil then
    raise ENetSock.Create('%s.SockInPending(SockIn=nil)',
      [ClassNameShort(self)^]);
  if aTimeOutMS < 0 then
    raise ENetSock.Create('%s.SockInPending(aTimeOutMS<0)',
      [ClassNameShort(self)^]);
  with PTextRec(SockIn)^ do
    result := BufEnd - BufPos;
  if result = 0 then
    // no data in SockIn^.Buffer, so try if some pending at socket level
    case SockReceivePending(aTimeOutMS) of
      cspDataAvailable:
        begin
          backup := fTimeOut;
          fTimeOut := 0; // not blocking call to fill SockIn buffer
          try
            // call InputSock() to actually retrieve any pending data
            if InputSock(PTextRec(SockIn)^) = NO_ERROR then
              with PTextRec(SockIn)^ do
                result := BufEnd - BufPos
            else
              result := -1; // indicates broken socket
          finally
            fTimeOut := backup;
          end;
        end;
      cspSocketError:
        result := -1; // indicates broken/closed socket
    end; // cspNoData will leave result=0
  {$ifdef OSWINDOWS}
  // under Unix SockReceivePending use poll(fSocket) and if data available
  // ioctl syscall is redundant
  if aPendingAlsoInSocket then
    // also includes data in socket bigger than TTextRec's buffer
    if (sock.RecvPending(insocket) = nrOK) and
       (insocket > 0) then
      inc(result, insocket);
  {$endif OSWINDOWS}
end;

function TCrtSocket.SockConnected: boolean;
var
  addr: TNetAddr;
begin
  result := SockIsDefined and
            (fSock.GetPeer(addr) = nrOK);
end;

procedure TCrtSocket.SockSend(P: pointer; Len: integer);
var
  cap: integer;
begin
  if Len <= 0 then
    exit;
  cap := Length(fSndBuf);
  if Len + fSndBufLen > cap then
    SetLength(fSndBuf, Len + cap + cap shr 3 + 2048);
  MoveFast(P^, PByteArray(fSndBuf)[fSndBufLen], Len);
  inc(fSndBufLen, Len);
end;

procedure TCrtSocket.SockSendCRLF;
var
  cap: integer;
begin
  cap := Length(fSndBuf);
  if fSndBufLen + 2 > cap then
    SetLength(fSndBuf, cap + cap shr 3 + 2048);
  PWord(@PByteArray(fSndBuf)[fSndBufLen])^ := $0a0d;
  inc(fSndBufLen, 2);
end;

procedure TCrtSocket.SockSend(const Values: array of const);
var
  i: PtrInt;
  tmp: ShortString;
begin
  for i := 0 to high(Values) do
    with Values[i] do
      case VType of
        vtString:
          SockSend(@VString^[1], PByte(VString)^);
        vtAnsiString:
          SockSend(VAnsiString, Length(RawByteString(VAnsiString)));
        {$ifdef HASVARUSTRING}
        vtUnicodeString:
          begin
            Unicode_WideToShort(VUnicodeString, // assume WinAnsi encoding
              length(UnicodeString(VUnicodeString)), CODEPAGE_US, tmp);
            SockSend(@tmp[1], Length(tmp));
          end;
        {$endif HASVARUSTRING}
        vtPChar:
          SockSend(VPChar, StrLen(VPChar));
        vtChar:
          SockSend(@VChar, 1);
        vtWideChar:
          SockSend(@VWideChar, 1); // only ansi part of the character
        vtInteger:
          begin
            Str(VInteger, tmp);
            SockSend(@tmp[1], Length(tmp));
          end;
        vtInt64 {$ifdef FPC}, vtQWord{$endif} :
          begin
            Str(VInt64^, tmp);
            SockSend(@tmp[1], Length(tmp));
          end;
      end;
  SockSendCRLF;
end;

procedure TCrtSocket.SockSend(const Line: RawByteString; NoCrLf: boolean);
begin
  if Line <> '' then
    SockSend(pointer(Line), Length(Line));
  if not NoCrLf then
    SockSendCRLF;
end;

function TCrtSocket.SockSendRemainingSize: integer;
begin
  result := Length(fSndBuf) - fSndBufLen;
end;

procedure TCrtSocket.SockSendFlush(const aBody: RawByteString);
var
  body: integer;
begin
  body := Length(aBody);
  if (body > 0) and
     (SockSendRemainingSize >= body) then // around 1800 bytes
  begin
    MoveFast(pointer(aBody)^, PByteArray(fSndBuf)[fSndBufLen], body);
    inc(fSndBufLen, body); // append to buffer as single TCP packet
    body := 0;
  end;
  {$ifdef SYNCRTDEBUGLOW}
  if Assigned(OnLog) then
  begin
    OnLog(sllCustom2, 'SockSend sock=% flush len=% body=% %', [fSock.Socket, fSndBufLen,
      Length(aBody), LogEscapeFull(pointer(fSndBuf), fSndBufLen)], self);
    if body > 0 then
      OnLog(sllCustom2, 'SockSend sock=% body len=% %', [fSock.Socket, body,
        LogEscapeFull(pointer(aBody), body)], self);
  end;
  {$endif SYNCRTDEBUGLOW}
  if fSndBufLen > 0 then
    if TrySndLow(pointer(fSndBuf), fSndBufLen) then
      fSndBufLen := 0
    else
      raise ENetSock.Create('%s.SockSendFlush(%s) len=%d',
        [ClassNameShort(self)^, fServer, fSndBufLen], NetLastError);
  if body > 0 then
    SndLow(pointer(aBody), body); // direct sending of biggest packets
end;

procedure TCrtSocket.SockSendStream(Stream: TStream; ChunkSize: integer);
var
  chunk: RawByteString;
  rd: integer;
  pos: Int64;
begin
  SetLength(chunk, ChunkSize);
  pos := 0;
  repeat
    rd := Stream.Read(pointer(chunk)^, ChunkSize);
    if rd = 0 then
      break;
    if not TrySndLow(pointer(chunk), rd) then
      raise ENetSock.Create('%s.SockSendStream(%s,%d) rd=%d pos=%d to %s:%s',
        [ClassNameShort(self)^, ClassNameShort(Stream)^, ChunkSize,
         rd, pos, fServer, fPort], NetLastError);
    inc(pos, rd);
  until false;
end;

procedure TCrtSocket.SockRecv(Buffer: pointer; Length: integer);
var
  read: integer;
begin
  read := Length;
  if not TrySockRecv(Buffer, read, {StopBeforeLength=}false) or
     (Length <> read) then
    raise ENetSock.Create('%s.SockRecv(%d) read=%d',
      [ClassNameShort(self)^, Length, read], NetLastError);
end;

function TCrtSocket.SockReceivePending(TimeOutMS: integer;
  loerr: system.PInteger): TCrtSocketPending;
var
  events: TNetEvents;
begin
  if loerr <> nil then
    loerr^ := 0;
  if SockIsDefined then
    events := fSock.WaitFor(TimeOutMS, [neRead], loerr)
  else
    events := [neError];
  if neError in events then
    result := cspSocketError
  else if neRead in events then
    result := cspDataAvailable
  else
    result := cspNoData;
end;

function TCrtSocket.SockReceiveString: RawByteString;
var
  available, resultlen, read: integer;
begin
  result := '';
  if not SockIsDefined then
    exit;
  resultlen := 0;
  repeat
    if fSock.RecvPending(available) <> nrOK then
      exit; // raw socket error
    if available = 0 then // no data in the allowed timeout
      if result = '' then
      begin
        // wait till something
        SleepHiRes(1); // some delay in infinite loop
        continue;
      end
      else
        break; // return what we have
    SetLength(result, resultlen + available); // append to result
    read := available;
    if not TrySockRecv(@PByteArray(result)[resultlen], read,
         {StopBeforeLength=}true) then
    begin
      Close;
      SetLength(result, resultlen);
      exit;
    end;
    inc(resultlen, read);
    if read < available then
      SetLength(result, resultlen); // e.g. Read=0 may happen
    SleepHiRes(0); // 10us on POSIX, SwitchToThread on Windows
  until false;
end;

function TCrtSocket.TrySockRecv(Buffer: pointer; var Length: integer;
  StopBeforeLength: boolean): boolean;
var
  expected, read: integer;
  events: TNetEvents;
  res: TNetResult;
begin
  result := false;
  if SockIsDefined and
     (Buffer <> nil) and
     (Length > 0) then
  begin
    expected := Length;
    Length := 0;
    repeat
      read := expected - Length;
      if fSecure <> nil then
        res := fSecure.Receive(Buffer, read)
      else
        res := fSock.Recv(Buffer, read);
      if res <> nrOK then
      begin
        // no more to read, or socket closed/broken
        {$ifdef SYNCRTDEBUGLOW}
        if Assigned(OnLog) then
          OnLog(sllCustom2, 'TrySockRecv: sock=% Recv=% %',
            [fSock.Socket, read, SocketErrorMessage], self);
        {$endif SYNCRTDEBUGLOW}
        if StopBeforeLength and
           (res = nrRetry) then // no more to read
          break;
        Close; // connection broken or socket closed gracefully
        exit;
      end
      else
      begin
        inc(fBytesIn, read);
        inc(Length, read);
        if StopBeforeLength or
           (Length = expected) then
          break; // good enough for now
        inc(PByte(Buffer), read);
      end;
      events := fSock.WaitFor(TimeOut, [neRead]);
      if neError in events then
      begin
        Close; // connection broken or socket closed gracefully
        exit;
      end
      else if neRead in events then
        continue;
      if Assigned(OnLog) then
        OnLog(sllTrace, 'TrySockRecv: timeout after %ms)', [TimeOut], self);
      exit; // identify read timeout as error
    until false;
    result := true;
  end;
end;

procedure TCrtSocket.SockRecvLn(out Line: RawUtf8; CROnly: boolean);

  procedure RecvLn(var Line: RawUtf8);
  var
    P: PAnsiChar;
    LP, L: PtrInt;
    tmp: array[0..1023] of AnsiChar; // avoid ReallocMem() every char
  begin
    P := @tmp;
    Line := '';
    repeat
      SockRecv(P, 1); // this is very slow under Windows -> use SockIn^ instead
      if P^ <> #13 then // at least NCSA 1.3 does send a #10 only -> ignore #13
        if P^ = #10 then
        begin
          if Line = '' then // get line
            FastSetString(Line, @tmp, P - tmp)
          else
          begin
            // append to already read chars
            LP := P - tmp;
            L := Length(Line);
            Setlength(Line, L + LP);
            MoveFast(tmp, PByteArray(Line)[L], LP);
          end;
          exit;
        end
        else if P = @tmp[high(tmp)] then
        begin
          // tmp[] buffer full? -> append to already read chars
          L := Length(Line);
          Setlength(Line, L + SizeOf(tmp));
          MoveFast(tmp, PByteArray(Line)[L], SizeOf(tmp));
          P := tmp;
        end
        else
          inc(P);
    until false;
  end;

var
  c: byte;
  L, Error: PtrInt;
begin
  if CROnly then
  begin
    // slower but accurate version expecting #13 as line end
    // SockIn^ expect either #10, either #13#10 -> a dedicated version is needed
    repeat
      SockRecv(@c, 1); // this is slow but works
      if c in [0, 13] then
        exit; // end of line
      L := Length({%H-}Line);
      SetLength(Line, L + 1);
      PByteArray(Line)[L] := c;
    until false;
  end
  else if SockIn <> nil then
  begin
    {$I-}
    readln(SockIn^, Line); // example: HTTP/1.0 200 OK
    Error := ioresult;
    if Error <> 0 then
      raise ENetSock.Create('%s.SockRecvLn error %d after %d chars',
        [ClassNameShort(self)^, Error, Length(Line)]);
    {$I+}
  end
  else
    RecvLn(Line); // slow under Windows -> use SockIn^ instead
end;

procedure TCrtSocket.SockRecvLn;
var
  c: AnsiChar;
  Error: integer;
begin
  if SockIn <> nil then
  begin
    {$I-}
    readln(SockIn^);
    Error := ioresult;
    if Error <> 0 then
      raise ENetSock.Create('%s.SockRecvLn error %d',
        [ClassNameShort(self)^, Error]);
    {$I+}
  end
  else
    repeat
      SockRecv(@c, 1);
    until c = #10;
end;

procedure TCrtSocket.SndLow(P: pointer; Len: integer);
begin
  if not TrySndLow(P, Len) then
    raise ENetSock.Create('%s.SndLow(%s) len=%d',
      [ClassNameShort(self)^, fServer, Len], NetLastError);
end;

procedure TCrtSocket.SndLow(const Data: RawByteString);
begin
  SndLow(pointer(Data), Length(Data));
end;

function TCrtSocket.TrySndLow(P: pointer; Len: integer): boolean;
var
  sent: integer;
  events: TNetEvents;
  res: TNetResult;
begin
  result := Len = 0;
  if not SockIsDefined or
     (Len <= 0) or
     (P = nil) then
    exit;
  repeat
    sent := Len;
    if fSecure <> nil then
      res := fSecure.Send(P, sent)
    else
      res := fSock.Send(P, sent);
    if sent > 0 then
    begin
      inc(fBytesOut, sent);
      dec(Len, sent);
      if Len <= 0 then
        break; // data successfully sent
      inc(PByte(P), sent);
    end
    else if (res <> nrOK) and
            (res <> nrRetry) then
      exit; // fatal socket error
    events := fSock.WaitFor(TimeOut, [neWrite]);
    if (neError in events) or
       not (neWrite in events) then // identify timeout as error
      exit;
  until false;
  result := true;
end;

function TCrtSocket.LastLowSocketError: integer;
begin
  result := sockerrno;
end;

function TCrtSocket.AcceptIncoming(
  ResultClass: TCrtSocketClass; Async: boolean): TCrtSocket;
var
  client: TNetSocket;
  addr: TNetAddr;
begin
  result := nil;
  if not SockIsDefined then
    exit;
  if fSock.Accept(client, addr, Async) <> nrOK then
    exit;
  if ResultClass = nil then
    ResultClass := TCrtSocket;
  result := ResultClass.Create(Timeout);
  result.AcceptRequest(client, @addr);
  result.CreateSockIn; // use SockIn with 1KB input buffer: 2x faster
end;

function TCrtSocket.PeerAddress(LocalAsVoid: boolean): RawUtf8;
begin
  if fPeerAddr = nil then
    result := ''
  else
    fPeerAddr^.IP(result, LocalAsVoid);
end;

function TCrtSocket.PeerPort: TNetPort;
begin
  if fPeerAddr = nil then
    result := 0
  else
    result := fPeerAddr^.Port;
end;


function SocketOpen(const aServer, aPort: RawUtf8; aTLS: boolean;
  aTLSContext: PNetTlsContext; aTunnel: PUri): TCrtSocket;
begin
  try
    result := TCrtSocket.Open(
      aServer, aPort, nlTcp, 10000, aTLS, aTLSContext, aTunnel);
  except
    result := nil;
  end;
end;


initialization
  IP4local := cLocalhost; // use var string with refcount=1 to avoid allocation
  assert(SizeOf(in_addr) = 4);
  assert(SizeOf(in6_addr) = 16);
  assert(SizeOf(sockaddr_in) = 16);
  assert(SizeOf(TNetAddr) = SOCKADDR_SIZE);
  assert(SizeOf(TNetAddr) >=
    {$ifdef OSWINDOWS} SizeOf(sockaddr_in6) {$else} SizeOf(sockaddr_un) {$endif});
  DefaultListenBacklog := SOMAXCONN;
  GetSystemMacAddress := @_GetSystemMacAddress;
  InitializeUnit; // in mormot.net.sock.windows/posix.inc

finalization
  FinalizeUnit;

end.

