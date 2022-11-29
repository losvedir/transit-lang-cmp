/// low-level access to the SSPI/SChannel API for Win32/Win64
// - this unit is a part of the Open Source Synopse mORMot framework 2,
// licensed under a MPL/GPL/LGPL three license - see LICENSE.md
unit mormot.lib.sspi;


{
  *****************************************************************************

   Security Support Provider Interface (SSPI) Support on Windows
   - Low-Level SSPI/SChannel Functions
   - Middle-Level SSPI Wrappers
   - High-Level Client and Server Authentication using SSPI
   - Lan Manager Access Functions

  *****************************************************************************

}

interface

{$I ..\mormot.defines.inc}

{$ifdef OSPOSIX}

// do-nothing-unit on non Windows system

implementation

{$else}

uses
  sysutils,
  classes,
  mormot.core.base,
  mormot.core.os;
  // since we use it from mormot.net.sock, we avoid mormot.core.unicode


{ ****************** Low-Level SSPI/SChannel Functions }

type
  LONG_PTR = PtrInt;
  
  TTimeStamp = record
    dwLowDateTime: cardinal;
    dwHighDateTime: cardinal;
  end;
  PTimeStamp = ^TTimeStamp;


  ALG_ID = cardinal;
  TALG_IDs = array[word] of ALG_ID;
  PALG_IDs = ^TALG_IDs;

  /// SSPI context handle
  TSecHandle = record
    dwLower: LONG_PTR;
    dwUpper: LONG_PTR;
  end;
  PSecHandle = ^TSecHandle;

  // some context aliases, as defined in SSPI headers
  TCredHandle = type TSecHandle;
  PCredHandle = type PSecHandle;
  TCtxtHandle = type TSecHandle;
  PCtxtHandle = type PSecHandle;

  /// SSPI context
  TSecContext = record
    ID: Int64;
    CredHandle: TSecHandle;
    CtxHandle: TSecHandle;
    CreatedTick64: Int64;
  end;
  PSecContext = ^TSecContext;

  /// dynamic array of SSPI contexts
  // - used to hold information between calls to ServerSspiAuth
  TSecContextDynArray = array of TSecContext;

  /// defines a SSPI buffer
  {$ifdef USERECORDWITHMETHODS}
  TSecBuffer = record
  {$else}
  TSecBuffer = object
  {$endif USERECORDWITHMETHODS}
  public
    cbBuffer: cardinal;
    BufferType: cardinal;
    pvBuffer: pointer;
    procedure Init(aType: cardinal; aData: pointer; aSize: cardinal);
  end;
  PSecBuffer = ^TSecBuffer;

  /// describes a SSPI buffer
  {$ifdef USERECORDWITHMETHODS}
  TSecBufferDesc = record
  {$else}
  TSecBufferDesc = object
  {$endif USERECORDWITHMETHODS}
  public
    ulVersion: cardinal;
    cBuffers: cardinal;
    pBuffers: PSecBuffer;
    procedure Init(aVersion: cardinal;
      aBuffers: PSecBuffer; aBuffersCount: cardinal);
  end;
  PSecBufferDesc = ^TSecBufferDesc;

  /// store the name associated with the context
  SecPkgContext_NamesW = record
    sUserName: PWideChar;
  end;

  /// store information about a SSPI package
  TSecPkgInfoW = record
    fCapabilities: cardinal;
    wVersion: Word;
    wRPCID: Word;
    cbMaxToken: cardinal;
    Name: PWideChar;
    Comment: PWideChar;
  end;
  /// pointer to information about a SSPI package
  PSecPkgInfoW = ^TSecPkgInfoW;

  /// store negotation information about a SSPI package
  TSecPkgContext_NegotiationInfo = record
    PackageInfo: PSecPkgInfoW;
    NegotiationState: cardinal;
  end;

  /// store various working buffer sizes of a SSPI command
  TSecPkgContext_Sizes = record
    cbMaxToken: cardinal;
    cbMaxSignature: cardinal;
    cbBlockSize: cardinal;
    cbSecurityTrailer: cardinal;
  end;

  /// store various working buffer sizes of a SSPI stream
  TSecPkgContext_StreamSizes = record
    cbHeader: cardinal;
    cbTrailer: cardinal;
    cbMaximumMessage: cardinal;
    cBuffers: cardinal;
    cbBlockSize: cardinal;
  end;

  /// information about SSPI supported algorithm
  TSecPkgCred_SupportedAlgs = record
    cSupportedAlgs: cardinal;
    palgSupportedAlgs: pointer;
  end;
  /// pointer to SSPI supported algorithm
  PSecPkgCred_SupportedAlgs = ^TSecPkgCred_SupportedAlgs;

  /// information about a SSPI connection (XP's SECPKG_ATTR_CONNECTION_INFO)
  {$ifdef USERECORDWITHMETHODS}
  TSecPkgConnectionInfo = record
  {$else}
  TSecPkgConnectionInfo = object
  {$endif USERECORDWITHMETHODS}
    dwProtocol: cardinal;
    aiCipher: ALG_ID;
    dwCipherStrength: cardinal;
    aiHash: ALG_ID;
    dwHashStrength: cardinal;
    aiExch: ALG_ID;
    dwExchStrength: cardinal;
    /// retrieve some decoded text representation of this raw information
    // - typically 'ECDHE256-AES128-SHA256 TLSv1.2'
    function ToText: RawUtf8;
  end;
  PSecPkgConnectionInfo = ^TSecPkgConnectionInfo;

  TSecPkgCipherInfoText = array[0..63] of WideChar;

  /// information about a SSPI connection (Vista+ SECPKG_ATTR_CIPHER_INFO)
  TSecPkgCipherInfo = record
    /// should be set to SECPKGCONTEXT_CIPHERINFO_V1
    dwVersion: cardinal;
    dwProtocol: cardinal;
    dwCipherSuite: cardinal;
    dwBaseCipherSuite: cardinal;
    /// fully qualified connection name
    // - e.g. 'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384_P384'
    szCipherSuite: TSecPkgCipherInfoText;
    szCipher: TSecPkgCipherInfoText;
    dwCipherLen: cardinal;
    dwCipherBlockLen: cardinal;    // in bytes
    szHash: TSecPkgCipherInfoText;
    dwHashLen: cardinal;
    szExchange: TSecPkgCipherInfoText;
    dwMinExchangeLen: cardinal;
    dwMaxExchangeLen: cardinal;
    szCertificate: TSecPkgCipherInfoText;  // e.g. 'RSA'
    dwKeyType: cardinal;
  end;

  /// information about SSPI Authority Identify
  TSecWinntAuthIdentityW = record
    User: PWideChar;
    UserLength: cardinal;
    Domain: PWideChar;
    DomainLength: cardinal;
    Password: PWideChar;
    PasswordLength: cardinal;
    Flags: cardinal
  end;
  /// pointer to SSPI Authority Identify
  PSecWinntAuthIdentityW = ^TSecWinntAuthIdentityW;

const
  SECBUFFER_VERSION = 0;

  SECBUFFER_EMPTY          = 0;
  SECBUFFER_DATA           = 1;
  SECBUFFER_TOKEN          = 2;
  SECBUFFER_EXTRA          = 5;
  SECBUFFER_STREAM_TRAILER = 6;
  SECBUFFER_STREAM_HEADER  = 7;
  SECBUFFER_PADDING        = 9;
  SECBUFFER_STREAM         = 10;
  SECBUFFER_ALERT          = 17;

  SECPKG_CRED_INBOUND  = 1;
  SECPKG_CRED_OUTBOUND = 2;

  SECPKG_ATTR_SIZES            = 0;
  SECPKG_ATTR_NAMES            = 1;
  SECPKG_ATTR_STREAM_SIZES     = 4;
  SECPKG_ATTR_NEGOTIATION_INFO = 12;
  SECPKG_ATTR_CONNECTION_INFO  = $5a;
  SECPKG_ATTR_CIPHER_INFO      = $64; // Vista+ new API

  SECPKGCONTEXT_CIPHERINFO_V1 = 1;

  SECURITY_NETWORK_DREP = 0;
  SECURITY_NATIVE_DREP  = $10;

  ISC_REQ_DELEGATE           = $00000001;
  ISC_REQ_MUTUAL_AUTH        = $00000002;
  ISC_REQ_REPLAY_DETECT      = $00000004;
  ISC_REQ_SEQUENCE_DETECT    = $00000008;
  ISC_REQ_CONFIDENTIALITY    = $00000010;
  ISC_REQ_USE_SESSION_KEY    = $00000020;
  ISC_REQ_PROMPT_FOR_CREDS   = $00000040;
  ISC_REQ_USE_SUPPLIED_CREDS = $00000080;
  ISC_REQ_ALLOCATE_MEMORY    = $00000100;
  ISC_REQ_USE_DCE_STYLE      = $00000200;
  ISC_REQ_DATAGRAM           = $00000400;
  ISC_REQ_CONNECTION         = $00000800;
  ISC_REQ_CALL_LEVEL         = $00001000;
  ISC_REQ_FRAGMENT_SUPPLIED  = $00002000;
  ISC_REQ_EXTENDED_ERROR     = $00004000;
  ISC_REQ_STREAM             = $00008000;
  ISC_REQ_INTEGRITY          = $00010000;
  ISC_REQ_IDENTIFY           = $00020000;
  ISC_REQ_NULL_SESSION       = $00040000;
  ISC_REQ_MANUAL_CRED_VALIDATION = $00080000;
  ISC_REQ_RESERVED1          = $00100000;
  ISC_REQ_FRAGMENT_TO_FIT    = $00200000;
  ISC_REQ_FLAGS = ISC_REQ_SEQUENCE_DETECT or
                  ISC_REQ_REPLAY_DETECT or
                  ISC_REQ_CONFIDENTIALITY or
                  ISC_REQ_EXTENDED_ERROR or
                  ISC_REQ_ALLOCATE_MEMORY or
                  ISC_REQ_STREAM;

  ASC_REQ_REPLAY_DETECT   = $00000004;
  ASC_REQ_SEQUENCE_DETECT = $00000008;
  ASC_REQ_CONFIDENTIALITY = $00000010;
  ASC_REQ_ALLOCATE_MEMORY = $00000100;
  ASC_REQ_EXTENDED_ERROR  = $00008000;
  ASC_REQ_STREAM          = $00010000;
  ASC_REQ_FLAGS = ASC_REQ_SEQUENCE_DETECT or
                  ASC_REQ_REPLAY_DETECT or
                  ASC_REQ_CONFIDENTIALITY or
                  ASC_REQ_EXTENDED_ERROR or
                  ASC_REQ_ALLOCATE_MEMORY or
                  ASC_REQ_STREAM;

  SEC_E_OK = 0;

  SEC_I_CONTINUE_NEEDED        = $00090312;
  SEC_I_COMPLETE_NEEDED        = $00090313;
  SEC_I_COMPLETE_AND_CONTINUE  = $00090314;
  SEC_I_CONTEXT_EXPIRED	       = $00090317;
  SEC_I_INCOMPLETE_CREDENTIALS = $00090320;
  SEC_I_RENEGOTIATE            = $00090321;
  SEC_E_INCOMPLETE_MESSAGE     = $80090318;
  SEC_E_INVALID_TOKEN          = $80090308;
  SEC_E_ILLEGAL_MESSAGE        = $80090326;
  SEC_E_CERT_UNKNOWN           = $80090327;
  SEC_E_CERT_EXPIRED           = $80090328;
  SEC_E_ALGORITHM_MISMATCH     = $80090331;

  SEC_WINNT_AUTH_IDENTITY_UNICODE = $02;

  SCHANNEL_SHUTDOWN = 1;
  SCHANNEL_CRED_VERSION = 4;

function SspiResToText(res: cardinal): string;


// secur32.dll API calls

function QuerySecurityPackageInfoW(pszPackageName: PWideChar;
  var ppPackageInfo: PSecPkgInfoW): integer; stdcall;

function AcquireCredentialsHandleW(pszPrincipal, pszPackage: PWideChar;
  fCredentialUse: cardinal; pvLogonId: pointer; pAuthData: PSecWinntAuthIdentityW;
  pGetKeyFn: pointer; pvGetKeyArgument: pointer; phCredential: PSecHandle;
  ptsExpiry: PTimeStamp): integer; stdcall;

function InitializeSecurityContextW(phCredential: PSecHandle; phContext: PSecHandle;
  pszTargetName: PWideChar; fContextReq, Reserved1, TargetDataRep: cardinal;
  pInput: PSecBufferDesc; Reserved2: cardinal; phNewContext: PSecHandle;
  pOutput: PSecBufferDesc; var pfContextAttr: cardinal;
  ptsExpiry: PTimeStamp): integer; stdcall;

function AcceptSecurityContext(phCredential: PSecHandle; phContext: PSecHandle;
  pInput: PSecBufferDesc; fContextReq, TargetDataRep: cardinal;
  phNewContext: PSecHandle; pOutput: PSecBufferDesc; var pfContextAttr: cardinal;
  ptsExpiry: PTimeStamp): integer; stdcall;

function CompleteAuthToken(phContext: PSecHandle;
  pToken: PSecBufferDesc): integer; stdcall;

function QueryContextAttributesW(phContext: PSecHandle; ulAttribute: cardinal;
  pBuffer: pointer): integer; stdcall;

function ApplyControlToken(phContext: PCtxtHandle;
  pInput: PSecBufferDesc): cardinal; stdcall;

function QuerySecurityContextToken(phContext: PSecHandle;
  var Token: THandle): integer; stdcall;

function EncryptMessage(phContext: PSecHandle; fQOP: cardinal;
  pToken: PSecBufferDesc; MessageSeqNo: cardinal): integer; stdcall;

function DecryptMessage(phContext: PSecHandle; pToken: PSecBufferDesc;
  MessageSeqNo: cardinal; var fQOP: cardinal): integer; stdcall;

function FreeContextBuffer(pvContextBuffer: pointer): integer; stdcall;

function DeleteSecurityContext(phContext: PSecHandle): integer; stdcall;

function FreeCredentialsHandle(phCredential: PSecHandle): integer; stdcall;


type
  HCRYPTPROV = pointer;
  HCERTSTORE = pointer;
  PCCERT_CONTEXT = pointer;
  _HMAPPER = pointer;

  /// SChannel credential information
  TSChannelCred = record
    dwVersion: cardinal;
    cCreds: cardinal;
    paCred: PCCERT_CONTEXT;
    hRootStore: HCERTSTORE;
    cMappers: cardinal;
    aphMappers: _HMAPPER;
    cSupportedAlgs: cardinal;
    palgSupportedAlgs: PALG_IDs;
    grbitEnabledProtocols: cardinal;
    dwMinimumCipherStrength: cardinal;
    dwMaximumCipherStrength: cardinal;
    dwSessionLifespan: cardinal;
    dwFlags: cardinal;
    dwCredFormat: cardinal;
  end;
  /// pointer to SChannel credential information
  PSChannelCred = ^TSChannelCred;

  /// store a memory buffer during SChannel encryption
  TCryptDataBlob = record
    cbData: Cardinal;
    pbData: Pointer;
  end;

const
  UNISP_NAME = 'Microsoft Unified Security Protocol Provider';

  SP_PROT_TLS1          = $0C0;
  SP_PROT_TLS1_SERVER   = $040;
  SP_PROT_TLS1_CLIENT   = $080;
  SP_PROT_TLS1_1        = $300;
  SP_PROT_TLS1_1_SERVER = $100;
  SP_PROT_TLS1_1_CLIENT = $200;
  SP_PROT_TLS1_2        = $C00;
  SP_PROT_TLS1_2_SERVER = $400;
  SP_PROT_TLS1_2_CLIENT = $800;
  SP_PROT_TLS1_3        = $3000; // Windows Server 2022 ;)
  SP_PROT_TLS1_3_SERVER = $1000;
  SP_PROT_TLS1_3_CLIENT = $2000 ;

  PKCS12_INCLUDE_EXTENDED_PROPERTIES = $10;

  CERT_FIND_ANY = 0;

  // no check is made to determine whether memory for contexts remains allocated
  CERT_CLOSE_STORE_DEFAULT = 0;
  // force freeing all contexts associated with the store
  CERT_CLOSE_STORE_FORCE_FLAG = 1;
  // checks for nonfreed certificate, CRL, and CTL context to report an error on leak
  CERT_CLOSE_STORE_CHECK_FLAG = 2;


// crypt32.dll API calls

function CertOpenStoreW(lpszStoreProvider: PWideChar; dwEncodingType: cardinal;
  hCryptProv: HCRYPTPROV; dwFlags: cardinal; pvPara: pointer): HCERTSTORE; stdcall;

function CertOpenSystemStoreW(hProv: HCRYPTPROV;
  szSubsystemProtocol: PWideChar): HCERTSTORE; stdcall;

function CertCloseStore(hCertStore: HCERTSTORE; dwFlags: cardinal): BOOL; stdcall;

function CertFindCertificateInStore(hCertStore: HCERTSTORE;
  dwCertEncodingType, dwFindFlags, dwFindType: cardinal; pvFindPara: pointer;
  pPrevCertContext: PCCERT_CONTEXT): PCCERT_CONTEXT; stdcall;

function PFXImportCertStore(pPFX: pointer; szPassword: PWideChar;
  dwFlags: cardinal): HCERTSTORE; stdcall;

function CertFreeCertificateContext(pCertContext: PCCERT_CONTEXT): BOOL; stdcall;


{ ****************** Middle-Level SSPI Wrappers }


type
  /// exception class raised during SSPI process
  ESynSspi = class(ExceptionWithProps)
  public
    constructor CreateLastOSError(const aContext: TSecContext);
  end;


/// set aSecHandle fields to empty state for a given connection ID
procedure InvalidateSecContext(var aSecContext: TSecContext;
  aConnectionID: Int64);

/// free aSecContext on client or server side
procedure FreeSecContext(var aSecContext: TSecContext);

/// encrypt a message
// - aSecContext must be set e.g. from previous success call to ServerSspiAuth
// or ClientSspiAuth
// - aPlain contains data that must be encrypted
// - returns encrypted message
function SecEncrypt(var aSecContext: TSecContext;
  const aPlain: RawByteString): RawByteString;

/// decrypt a message
// - aSecContext must be set e.g. from previous success call to ServerSspiAuth
// or ClientSspiAuth
// - aEncrypted contains data that must be decrypted
// - returns decrypted message
// - warning: aEncrypted is modified in-place during the process
function SecDecrypt(var aSecContext: TSecContext;
  var aEncrypted: RawByteString): RawByteString;

/// retrieve the connection information text of a given TLS connection
function TlsConnectionInfo(var Ctxt: TCtxtHandle): RawUtf8;


{ ****************** High-Level Client and Server Authentication using SSPI }

/// client-side authentication procedure
// - aSecContext holds information between function calls
// - aInData contains data received from server
// - aSecKerberosSpn is the optional SPN domain name, e.g.
// 'mymormotservice/myserver.mydomain.tld'
// - aOutData contains data that must be sent to server
// - if function returns True, client must send aOutData to server
// and call function again with the data returned from servsr
function ClientSspiAuth(var aSecContext: TSecContext;
  const aInData: RawByteString; const aSecKerberosSpn: RawUtf8;
  out aOutData: RawByteString): boolean;

/// client-side authentication procedure with clear text password
//  - this function must be used when application need to use different
// user credentials (not credentials of logged-in user)
// - aSecContext holds information between function calls
// - aInData contains data received from server
// - aUserName is the domain and user name, in form of
// 'DomainName\UserName'
// - aPassword is the user clear text password
// - aOutData contains data that must be sent to server
// - if function returns True, client must send aOutData to server
// and call function again with the data returned from server
function ClientSspiAuthWithPassword(var aSecContext: TSecContext;
  const aInData: RawByteString; const aUserName: RawUtf8;
  const aPassword: RawUtf8; out aOutData: RawByteString): boolean;

/// server-side authentication procedure
// - aSecContext holds information between function calls
// - aInData contains data recieved from client
// - aOutData contains data that must be sent to client
// - if this function returns True, server must send aOutData to client
// and call function again with the data returned from client
function ServerSspiAuth(var aSecContext: TSecContext;
  const aInData: RawByteString; out aOutData: RawByteString): boolean;

/// Server-side function that returns authenticated user name
// - aSecContext must be received from a previous successful call to
// ServerSspiAuth()
// - aUserName contains authenticated user name
procedure ServerSspiAuthUser(var aSecContext: TSecContext;
  out aUserName: RawUtf8);

/// return the name of the security package that has been used
// during the negotiation process
// - aSecContext must be received from previous successful call to
// ServerSspiAuth() or ClientSspiAuth()
function SecPackageName(var aSecContext: TSecContext): RawUtf8;

/// force using a Kerberos SPN for server identification
// - aSecKerberosSpn is the Service Principal Name, as registered in domain,
// e.g. 'mymormotservice/myserver.mydomain.tld@MYDOMAIN.TLD'
procedure ClientForceSpn(const aSecKerberosSpn: RawUtf8);

/// high-level cross-platform initialization function
// - as called e.g. by mormot.rest.client/server.pas
// - in this unit, will just call ServerForceNTLM(false)
function InitializeDomainAuth: boolean;


const
  /// character used as marker in user name to indicates the associated domain
  SSPI_USER_CHAR = '\';

  // SSPI package names. Client always use Negotiate
  // Server detect Negotiate or NTLM requests and use appropriate package
  SECPKGNAMENTLM = 'NTLM';
  SECPKGNAMENEGOTIATE = 'Negotiate';

var
  /// HTTP Challenge name for SSPI authentication
  // - call ServerForceNTLM() to specialize this value to 'NTLM' or 'Negotiate'
  SECPKGNAMEHTTP: RawUtf8;

  /// HTTP Challenge name, converted into uppercase for IdemPChar() pattern
  SECPKGNAMEHTTP_UPPER: RawUtf8;

  /// HTTP header to be set for SSPI authentication
  // - call ServerForceNTLM() to specialize this value to either
  // 'WWW-Authenticate: NTLM' or 'WWW-Authenticate: Negotiate';
  SECPKGNAMEHTTPWWWAUTHENTICATE: RawUtf8;

  /// HTTP header pattern received for SSPI authentication
  // - call ServerForceNTLM() to specialize this value to either
  // 'AUTHORIZATION: NTLM ' or 'AUTHORIZATION: NEGOTIATE '
  SECPKGNAMEHTTPAUTHORIZATION: RawUtf8;

  /// by default, this unit will use Negotiate/Kerberos for client authentication
  // - can be set to TRUE to use the deprecated and unsafe NTLM protocol instead
  // - use case: SPNs not configured properly in domain
  // - see for details https://synopse.info/forum/viewtopic.php?id=931&p=3
  SspiForceNtlmClient: boolean = false;


{ ****************** Lan Manager Access Functions }

// netapi32.dll API calls

const
  netapi32 = 'netapi32.dll';

  MAX_PREFERRED_LENGTH = cardinal(-1);
  LG_INCLUDE_INDIRECT = 1;
  NERR_Success = 0;

type
  TNetApiStatus = cardinal;

  // _USER_INFO_0, _LOCALGROUP_MEMBERS_INFO_3 and _LOCALGROUP_INFO_0 do match
  TGroupInfo0 = record
    name: PWideChar;
  end;
  PGroupInfo0 = ^TGroupInfo0;
  TGroupInfo0Array = array[0..MaxInt div SizeOf(TGroupInfo0) - 1] of TGroupInfo0;
  PGroupInfo0Array = ^TGroupInfo0Array;

  TGroupInfo1 = record
    name: PWideChar;
    comment: PWideChar;
  end;
  PGroupInfo1 = ^TGroupInfo1;

  TGroupInfo3 = record
    name: PWideChar;
    comment: PWideChar;
    group_sid: PSid;
    attributes: cardinal;
  end;
  PGroupInfo3 = ^TGroupInfo3;

function NetApiBufferAllocate(ByteCount: cardinal;
  var Buffer: pointer): TNetApiStatus; stdcall;

function NetApiBufferFree(Buffer: pointer): TNetApiStatus; stdcall;

function NetApiBufferReallocate(OldBuffer: pointer; NewByteCount: cardinal;
  var NewBuffer: pointer): TNetApiStatus; stdcall;

function NetApiBufferSize(Buffer: pointer;
  var ByteCount: cardinal): TNetApiStatus; stdcall;


function NetUserAdd(servername: PWideChar; level: cardinal;
  buf: PByte; parm_err: PCardinal): TNetApiStatus; stdcall;

function NetUserEnum(servername: PWideChar; level, filter: cardinal;
  var bufptr: pointer; prefmaxlen: cardinal;
  entriesread, totalentries: PCardinal;
  resumehandle: PPCardinal = nil): TNetApiStatus; stdcall;

function NetUserGetInfo(servername, username: PWideChar; level: cardinal;
  var bufptr: pointer): TNetApiStatus; stdcall;

function NetUserSetInfo(servername, username: PWideChar; level: cardinal;
  buf: pointer; parm_err: PCardinal): TNetApiStatus; stdcall;

function NetUserDel(servername: PWideChar; username: PWideChar): TNetApiStatus; stdcall;

function NetUserGetGroups(servername, username: PWideChar; level: cardinal;
  var bufptr: pointer; prefmaxlen: cardinal;
  entriesread, totalentries: PCardinal): TNetApiStatus; stdcall;

function NetUserSetGroups(servername, username: PWideChar; level: cardinal;
  buf: pointer; num_entries: cardinal): TNetApiStatus; stdcall;

function NetUserGetLocalGroups(servername, username: PWideChar;
  level, flags: cardinal; var bufptr: pointer; prefmaxlen: cardinal;
  entriesread, totalentries: PCardinal): TNetApiStatus; stdcall;

function NetUserModalsGet(servername: PWideChar; level: cardinal;
  var bufptr: pointer): TNetApiStatus; stdcall;

function NetUserModalsSet(servername: PWideChar; level: cardinal;
  buf: pointer; parm_err: PCardinal): TNetApiStatus; stdcall;

function NetUserChangePassword(domainname, username,
  oldpassword, newpassword: PWideChar): TNetApiStatus; stdcall;


function NetGroupEnum(servername: PWideChar; level: cardinal;
  var bufptr: pointer; prefmaxlen: cardinal; entriesread, totalentries: PCardinal;
  resume_handle: PPCardinal = nil): TNetApiStatus; stdcall;


function NetLocalGroupAdd(servername: PWideChar; level: cardinal;
  buf: pointer; parm_err: PCardinal): TNetApiStatus; stdcall;

function NetLocalGroupAddMember(servername, groupname: PWideChar;
  membersid: PSID): TNetApiStatus; stdcall;

function NetLocalGroupEnum(servername: PWideChar; level: cardinal;
  var bufptr: pointer; prefmaxlen: cardinal; entriesread, totalentries: PCardinal;
  resumehandle: PPCardinal = nil): TNetApiStatus; stdcall;

function NetLocalGroupGetInfo(servername, groupname: PWideChar;
  level: cardinal; var bufptr: pointer): TNetApiStatus; stdcall;

function NetLocalGroupSetInfo(servername, groupname: PWideChar;
  level: cardinal; buf: pointer; parm_err: PCardinal): TNetApiStatus; stdcall;

function NetLocalGroupDel(servername: PWideChar;
  groupname: PWideChar): TNetApiStatus; stdcall;

function NetLocalGroupDelMember(servername: PWideChar;
  groupname: PWideChar; membersid: PSID): TNetApiStatus; stdcall;

function NetLocalGroupGetMembers(servername, localgroupname: PWideChar;
  level: cardinal; var bufptr: pointer; prefmaxlen: cardinal;
  entriesread, totalentries: PCardinal; resumehandle: PPCardinal): TNetApiStatus; stdcall;

function NetLocalGroupSetMembers(servername, groupname: PWideChar;
  level: cardinal; buf: pointer; totalentries: cardinal): TNetApiStatus; stdcall;

function NetLocalGroupAddMembers(servername, groupname: PWideChar;
  level: cardinal; buf: pointer; totalentries: cardinal): TNetApiStatus; stdcall;

function NetLocalGroupDelMembers(servername, groupname: PWideChar;
  level: cardinal; buf: pointer; totalentries: cardinal): TNetApiStatus; stdcall;


/// retrieves global group names to which a specified user belongs
// - server is the DNS or NetBIOS name of the remote server to query (typically
// '\\MyDomainNameDns') - if server is '', the local computer is used
// - user is typically 'user.name' or 'DOMAIN\user.name'
// - call NetUserGetGroups() unless Local is true for NetUserGetLocalGroups()
// - will return only the groups explicitly assigned to the user, not the
// nested groups assigned to other local groups
function GetGroups(const server, user: RawUtf8;
  Local: boolean = false): TRawUtf8DynArray; overload;

/// retrieve information about each global group names on a given server
// - server is the DNS or NetBIOS name of the remote server to query (typically
// '\\MyDomainNameDns') - if server is '', the local computer is used
// - call NetGroupEnum() API
// - return the group names, and optionally the associated SID text
function GetGroups(const server: RawUtf8; sid: PRawUtf8DynArray = nil;
  Local: boolean = false): TRawUtf8DynArray; overload;

/// retrieve the textual SID of a group name on a given server
// - server is the DNS or NetBIOS name of the remote server to query (typically
// '\\MyDomainNameDns') - if server is '', the local computer is used
// - call NetGroupEnum() API then filter for the first supplied GroupName
function GetGroupSid(const Server, GroupName: RawUtf8;
  Local: boolean = false): RawUtf8;

type
  TGetUsersFilterAccount = set of (
    gufTempDuplicate,
    gufNormal,
    gufProxyAccount,
    gufInterdomainTrust,
    gufWorkstationTrust,
    gufServerTrust);

///  retrieves information about all user accounts on a server
// - server is the DNS or NetBIOS name of the remote server to query (typically
// '\\MyDomainNameDns') - if server is '', the local computer is used
// - call NetUserEnum()
function GetUsers(const server: RawUtf8 = '';
  filter: TGetUsersFilterAccount = []): TRawUtf8DynArray;

/// retrieves local group names to which the current user belongs
// - call NetLocalGroupEnum()
function GetLocalGroups(const server: RawUtf8 = ''): TRawUtf8DynArray;

/// retrieves a list of the members of a particular local group
// - server is the DNS or NetBIOS name of the remote server to query (typically
// '\\MyDomainNameDns') - if server is '', the local computer is used
// - return the account and domain names of the local group member
// - call NetLocalGroupGetMembers()
function GetLocalGroupMembers(const server, group: RawUtf8): TRawUtf8DynArray;


implementation


{ ****************** Low-Level SSPI/SChannel Functions }

function SspiResToText(res: cardinal): string;
begin
  case res of
    SEC_E_OK:
      result := 'SEC_E_OK';
    SEC_I_CONTINUE_NEEDED:
      result := 'SEC_I_CONTINUE_NEEDED';
    SEC_I_CONTEXT_EXPIRED:
      result := 'SEC_I_CONTEXT_EXPIRED';
    SEC_I_INCOMPLETE_CREDENTIALS:
      result := 'SEC_I_INCOMPLETE_CREDENTIALS';
    SEC_I_RENEGOTIATE:
      result := 'SEC_I_RENEGOTIATE';
    SEC_E_INCOMPLETE_MESSAGE:
      result := 'SEC_E_INCOMPLETE_MESSAGE';
    SEC_E_INVALID_TOKEN:
      result := 'SEC_E_INVALID_TOKEN';
    SEC_E_ILLEGAL_MESSAGE:
      result := 'SEC_E_ILLEGAL_MESSAGE';
    SEC_E_CERT_UNKNOWN:
      result := 'SEC_E_CERT_UNKNOWN';
    SEC_E_CERT_EXPIRED:
      result := 'SEC_E_CERT_EXPIRED';
    SEC_E_ALGORITHM_MISMATCH:
      result := 'SEC_E_ALGORITHM_MISMATCH';
  else
    result := IntToStr(res);
  end;
end;


const
  secur32 = 'secur32.dll';

function QuerySecurityPackageInfoW;  external secur32;
function AcquireCredentialsHandleW;  external secur32;
function InitializeSecurityContextW; external secur32;
function AcceptSecurityContext;      external secur32;
function CompleteAuthToken;          external secur32;
function QueryContextAttributesW;    external secur32;
function ApplyControlToken;          external secur32;
function QuerySecurityContextToken;  external secur32;
function EncryptMessage;             external secur32;
function DecryptMessage;             external secur32;
function FreeContextBuffer;          external secur32;
function DeleteSecurityContext;      external secur32;
function FreeCredentialsHandle;      external secur32;

const
  crypt32 = 'crypt32.dll';

function CertOpenStoreW;             external crypt32;
function CertOpenSystemStoreW;       external crypt32;
function CertCloseStore;             external crypt32;
function CertFindCertificateInStore; external crypt32;
function PFXImportCertStore;         external crypt32;
function CertFreeCertificateContext; external crypt32;


{ TSecBuffer }

procedure TSecBuffer.Init(aType: cardinal; aData: pointer;
  aSize: cardinal);
begin
  BufferType := aType;
  pvBuffer := aData;
  cbBuffer := aSize;
end;


{ TSecBufferDesc }

procedure TSecBufferDesc.Init(aVersion: cardinal; aBuffers: PSecBuffer;
  aBuffersCount: cardinal);
begin
  ulVersion := aVersion;
  pBuffers := aBuffers;
  cBuffers := aBuffersCount;
end;


{ TSecPkgConnectionInfo }

procedure FixProtocol(var dwProtocol: cardinal);
begin
  if dwProtocol and SP_PROT_TLS1 <> 0 then
    dwProtocol := 0
  else if dwProtocol and SP_PROT_TLS1_1 <> 0 then
    dwProtocol := 1
  else if dwProtocol and SP_PROT_TLS1_2 <> 0 then
    dwProtocol := 2
  else if dwProtocol and SP_PROT_TLS1_3 <> 0 then
    dwProtocol := 3;
end;

function TSecPkgConnectionInfo.ToText: RawUtf8;
var
  h: byte;
  alg, hsh, xch: string[5];
begin
  FixProtocol(dwProtocol);
  if aiCipher and $1f in [14..17] then
    alg := 'AES'
  else if aiCipher = $6801 then
    alg := 'RC4-'
  else
    str(aiCipher and $1f, alg);
  h := aiHash and $1f;
  case h of
    1..2:
      hsh := 'MD';
    3:
      hsh := 'MD5-';
    4, 12..14:
      begin
        hsh := 'SHA';
        if dwHashStrength = 0 then
          case h of
            4:
              dwHashStrength := 1;
            12:
              dwHashStrength := 256;
            13:
              dwHashStrength := 384;
            14:
              dwHashStrength := 512;
          end;
      end;
    9:
      hsh := 'HMAC';
  else
    str(h, hsh);
  end;
  if (aiExch = $a400) or
     (aiExch = $2400) then
    xch := 'RSA'
  else if aiExch = $aa02 then
    xch := 'DH'
  else if aiExch = $aa05 then
    xch := 'ECDH'
  else if aiExch = $ae06 then
    xch := 'ECDHE'
  else if aiExch = $2203 then
    xch := 'ECDSA'
  else
    str(aiExch, xch);
  result := RawUtf8(format('%s%d-%s%d-%s%d TLSv1.%d ',
    [xch, dwExchStrength, alg, dwCipherStrength, hsh, dwHashStrength, dwProtocol]));
end;



{ ****************** Middle-Level SSPI Wrappers }

{ ESynSspi }

constructor ESynSspi.CreateLastOSError(const aContext: TSecContext);
var
  error: integer;
begin
  error := GetLastError;
  CreateFmt('SSPI API Error %x [%s] for ConnectionID=%d',
    [error, string(GetErrorText(error)), aContext.ID]);
end;


procedure InvalidateSecContext(var aSecContext: TSecContext;
  aConnectionID: Int64);
begin
  aSecContext.ID := aConnectionID;
  aSecContext.CredHandle.dwLower := -1;
  aSecContext.CredHandle.dwUpper := -1;
  aSecContext.CtxHandle.dwLower := -1;
  aSecContext.CtxHandle.dwUpper := -1;
  aSecContext.CreatedTick64 := 0;
end;

procedure FreeSecurityContext(var handle: TSecHandle);
begin
  if (handle.dwLower <> -1) or
     (handle.dwUpper <> -1) then
  begin
    DeleteSecurityContext(@handle);
    handle.dwLower := -1;
    handle.dwUpper := -1;
  end;
end;

procedure FreeCredentialsContext(var handle: TSecHandle);
begin
  if (handle.dwLower <> -1) or
     (handle.dwUpper <> -1) then
  begin
    FreeCredentialsHandle(@handle);
    handle.dwLower := -1;
    handle.dwUpper := -1;
  end;
end;

procedure FreeSecContext(var aSecContext: TSecContext);
begin
  FreeSecurityContext(aSecContext.CtxHandle);
  FreeCredentialsContext(aSecContext.CredHandle);
end;

function SecEncrypt(var aSecContext: TSecContext;
  const aPlain: RawByteString): RawByteString;
var
  Sizes: TSecPkgContext_Sizes;
  SrcLen, EncLen: cardinal;
  Token: array [0..127] of byte; // Usually 60 bytes
  Padding: array [0..63] of byte; // Usually 1 byte
  InBuf: array[0..2] of TSecBuffer;
  InDesc: TSecBufferDesc;
  EncBuffer: RawByteString;
  Status: integer;
  BufPtr: PByte;
begin
  // Sizes.cbSecurityTrailer is size of the trailer (signature + padding) block
  if QueryContextAttributesW(
       @aSecContext.CtxHandle, SECPKG_ATTR_SIZES, @Sizes) <> 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  // Encrypted data buffer structure:
  //
  // SSPI/Kerberos Interoperability with GSSAPI
  // https://msdn.microsoft.com/library/windows/desktop/aa380496.aspx
  //
  // GSS-API wrapper for Microsoft's Kerberos SSPI in Windows 2000
  // http://www.kerberos.org/software/samples/gsskrb5/gsskrb5/krb5/krb5msg.c
  //
  //   cbSecurityTrailer bytes   SrcLen bytes     cbBlockSize bytes or less
  //   (60 bytes)                                 (0 bytes, not used)
  // +-------------------------+----------------+--------------------------+
  // | Trailer                 | Data           | Padding                  |
  // +-------------------------+----------------+--------------------------+
  Assert(Sizes.cbSecurityTrailer <= High(Token)+1);
  {%H-}InBuf[0].Init(SECBUFFER_TOKEN, @Token[0], Sizes.cbSecurityTrailer);
  // Encoding done in-place, so we copy the data
  SrcLen := Length(aPlain);
  FastSetRawByteString(EncBuffer, pointer(aPlain), SrcLen);
  InBuf[1].Init(SECBUFFER_DATA, pointer(EncBuffer), SrcLen);
  Assert(Sizes.cbBlockSize <= High(Padding)+1);
  InBuf[2].Init(SECBUFFER_PADDING, @Padding[0], Sizes.cbBlockSize);
  InDesc.Init(SECBUFFER_VERSION, @InBuf, 3);
  Status := EncryptMessage(@aSecContext.CtxHandle, 0, @InDesc, 0);
  if Status < 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  EncLen := InBuf[0].cbBuffer + InBuf[1].cbBuffer + InBuf[2].cbBuffer;
  SetLength(result, EncLen);
  BufPtr := PByte(result);
  MoveFast(PByte(InBuf[0].pvBuffer)^, BufPtr^, InBuf[0].cbBuffer);
  Inc(BufPtr, InBuf[0].cbBuffer);
  MoveFast(PByte(InBuf[1].pvBuffer)^, BufPtr^, InBuf[1].cbBuffer);
  Inc(BufPtr, InBuf[1].cbBuffer);
  MoveFast(PByte(InBuf[2].pvBuffer)^, BufPtr^, InBuf[2].cbBuffer);
end;

function SecDecrypt(var aSecContext: TSecContext;
  var aEncrypted: RawByteString): RawByteString;
var
  EncLen, SigLen: cardinal;
  BufPtr: PByte;
  InBuf: array [0..1] of TSecBuffer;
  InDesc: TSecBufferDesc;
  Status: integer;
  QOP: cardinal;
begin
  EncLen := Length(aEncrypted);
  BufPtr := PByte(aEncrypted);
  if EncLen < SizeOf(cardinal) then
  begin
    SetLastError(ERROR_INVALID_PARAMETER);
    raise ESynSspi.CreateLastOSError(aSecContext);
  end;
  // Hack for compatibility with previous versions.
  // Should be removed in future.
  // Old version buffer format - first 4 bytes is Trailer length, skip it.
  // 16 bytes for NTLM and 60 bytes for Kerberos
  SigLen := PCardinal(BufPtr)^;
  if (SigLen = 16) or
     (SigLen = 60) then
  begin
    Inc(BufPtr, SizeOf(cardinal));
    Dec(EncLen, SizeOf(cardinal));
  end;
  {%H-}InBuf[0].Init(SECBUFFER_STREAM, BufPtr, EncLen);
  InBuf[1].Init(SECBUFFER_DATA, nil, 0);
  InDesc.Init(SECBUFFER_VERSION, @InBuf, 2);
  Status := DecryptMessage(@aSecContext.CtxHandle, @InDesc, 0, QOP);
  if Status < 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  FastSetRawByteString(result, InBuf[1].pvBuffer, InBuf[1].cbBuffer);
  FreeContextBuffer(InBuf[1].pvBuffer);
end;

function TlsConnectionInfo(var Ctxt: TCtxtHandle): RawUtf8;
var
  nfo: TSecPkgConnectionInfo;
  cip: TSecPkgCipherInfo; // Vista+ attribute
begin
  result := '';
  FillCharFast(nfo, SizeOf(nfo), 0);
  if QueryContextAttributesW(
      @Ctxt, SECPKG_ATTR_CONNECTION_INFO, @nfo) <> SEC_E_OK then
    exit;
  FillCharFast(cip, SizeOf(cip), 0);
  cip.dwVersion := SECPKGCONTEXT_CIPHERINFO_V1;
  if (OSVersion >= wVista) and
     (QueryContextAttributesW(
        @Ctxt, SECPKG_ATTR_CIPHER_INFO, @cip) = SEC_E_OK) and
     (cip.szCipherSuite[0] <> #0) then
  begin
    FixProtocol(nfo.dwProtocol); // cip.dwProtocol seems incorrect :(
    result := RawUtf8(format('%s TLSv1.%d ',
      [PWideChar(@cip.szCipherSuite), nfo.dwProtocol]));
  end
  else
    result := nfo.ToText; // fallback on XP
end;


{ ****************** High-Level Client and Server Authentication using SSPI }

var
  ForceSecKerberosSpn: SynUnicode;

function ClientSspiAuthWorker(var aSecContext: TSecContext;
  const aInData: RawByteString; pszTargetName: PWideChar;
  pAuthData: PSecWinntAuthIdentityW;
  out aOutData: RawByteString): boolean;
var
  InBuf: TSecBuffer;
  InDesc: TSecBufferDesc;
  InDescPtr: PSecBufferDesc;
  SecPkgInfo: PSecPkgInfoW;
  LInCtxPtr: PSecHandle;
  OutBuf: TSecBuffer;
  OutDesc: TSecBufferDesc;
  CtxReqAttr: cardinal;
  CtxAttr: cardinal;
  Status: Integer;
begin
  InBuf.BufferType := SECBUFFER_TOKEN;
  InBuf.cbBuffer := Length(aInData);
  InBuf.pvBuffer := PByte(aInData);
  if (aSecContext.CredHandle.dwLower = -1) and
     (aSecContext.CredHandle.dwUpper = -1) then
  begin
    aSecContext.CreatedTick64 := GetTickCount64;
    if QuerySecurityPackageInfoW(SECPKGNAMENEGOTIATE, SecPkgInfo) <> 0 then
      raise ESynSspi.CreateLastOSError(aSecContext);
    try
      if AcquireCredentialsHandleW(nil, SecPkgInfo^.Name, SECPKG_CRED_OUTBOUND,
          nil, pAuthData, nil, nil, @aSecContext.CredHandle, nil) <> 0 then
        raise ESynSspi.CreateLastOSError(aSecContext);
    finally
      FreeContextBuffer(SecPkgInfo);
    end;
    InDescPtr := nil;
    LInCtxPtr := nil;
  end
  else
  begin
    InDesc.ulVersion := SECBUFFER_VERSION;
    InDesc.cBuffers := 1;
    InDesc.pBuffers := @InBuf;
    InDescPtr := @InDesc;
    LInCtxPtr := @aSecContext.CtxHandle;
  end;
  CtxReqAttr := ISC_REQ_ALLOCATE_MEMORY or ASC_REQ_CONFIDENTIALITY;
  if pszTargetName <> nil then
    CtxReqAttr := CtxReqAttr or ISC_REQ_MUTUAL_AUTH;
  OutBuf.BufferType := SECBUFFER_TOKEN;
  OutBuf.cbBuffer := 0;
  OutBuf.pvBuffer := nil;
  OutDesc.ulVersion := SECBUFFER_VERSION;
  OutDesc.cBuffers := 1;
  OutDesc.pBuffers := @OutBuf;
  Status := InitializeSecurityContextW(@aSecContext.CredHandle, LInCtxPtr,
    pszTargetName, CtxReqAttr, 0, SECURITY_NATIVE_DREP, InDescPtr, 0,
    @aSecContext.CtxHandle, @OutDesc, CtxAttr, nil);
  result := (Status = SEC_I_CONTINUE_NEEDED) or
            (Status = SEC_I_COMPLETE_AND_CONTINUE);
  if (Status = SEC_I_COMPLETE_NEEDED) or
     (Status = SEC_I_COMPLETE_AND_CONTINUE) then
    Status := CompleteAuthToken(@aSecContext.CtxHandle, @OutDesc);
  if Status < 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  FastSetRawByteString(aOutData, OutBuf.pvBuffer, OutBuf.cbBuffer);
  FreeContextBuffer(OutBuf.pvBuffer);
end;

function ClientSspiAuth(var aSecContext: TSecContext;
  const aInData: RawByteString; const aSecKerberosSpn: RawUtf8;
  out aOutData: RawByteString): boolean;
var
  TargetName: PWideChar;
begin
  if aSecKerberosSpn <> '' then
    TargetName := pointer(SynUnicode(aSecKerberosSpn))
  else if ForceSecKerberosSpn <> '' then
    TargetName := pointer(ForceSecKerberosSpn)
  else
    TargetName := nil;
  result :=  ClientSspiAuthWorker(
    aSecContext, aInData, TargetName, nil, aOutData);
end;

function ClientSspiAuthWithPassword(var aSecContext: TSecContext;
  const aInData: RawByteString; const aUserName: RawUtf8;
  const aPassword: RawUtf8; out aOutData: RawByteString): boolean;
var
  UserPos: Integer;
  Domain, User, Password: SynUnicode;
  AuthIdentity: TSecWinntAuthIdentityW;
  TargetName: PWideChar;
begin
  UserPos := PosExChar('\', aUserName);
  if UserPos = 0 then
  begin
    Domain := '';
    User := SynUnicode(User);
  end
  else
  begin
    Domain := SynUnicode(Copy(aUserName, 1, UserPos - 1));
    User := SynUnicode(Copy(aUserName, UserPos + 1, MaxInt));
  end;
  PassWord := SynUnicode(aPassword);
  AuthIdentity.Domain := pointer(Domain);
  AuthIdentity.DomainLength := Length(Domain);
  AuthIdentity.User := pointer(User);
  AuthIdentity.UserLength := Length(User);
  AuthIdentity.Password := pointer(Password);
  AuthIdentity.PasswordLength := Length(Password);
  AuthIdentity.Flags := SEC_WINNT_AUTH_IDENTITY_UNICODE;
  if ForceSecKerberosSpn <> '' then
    TargetName := pointer(ForceSecKerberosSpn)
  else
    TargetName := nil;
  result :=  ClientSspiAuthWorker(
    aSecContext, aInData, TargetName, @AuthIdentity, aOutData);
end;

// mormot.core.unicode is overkill here - avoid a conversion with a temp string
function UpperCaseU(const S: RawByteString): RawUtf8;
var
  i, len: PtrInt;
  P: PByteArray;
begin
  len := length(S);
  FastSetString(result, pointer(S), len);
  P := pointer(result);
  for i := 0 to len - 1 do
    if P[i] in [ord('a')..ord('z')] then
      dec(P[i], 32);
end;

function ServerSspiAuth(var aSecContext: TSecContext;
  const aInData: RawByteString; out aOutData: RawByteString): boolean;
var
  InBuf: TSecBuffer;
  InDesc: TSecBufferDesc;
  SecPkgInfo: PSecPkgInfoW;
  LInCtxPtr: PSecHandle;
  OutBuf: TSecBuffer;
  OutDesc: TSecBufferDesc;
  CtxAttr: cardinal;
  Status: Integer;
begin
  InBuf.BufferType := SECBUFFER_TOKEN;
  InBuf.cbBuffer := Length(aInData);
  InBuf.pvBuffer := PByte(aInData);
  InDesc.ulVersion := SECBUFFER_VERSION;
  InDesc.cBuffers := 1;
  InDesc.pBuffers := @InBuf;
  if (aSecContext.CredHandle.dwLower = -1) and
     (aSecContext.CredHandle.dwUpper = -1) then
  begin
    aSecContext.CreatedTick64 := GetTickCount64;
    if UpperCaseU(copy(RawUtf8(aInData), 1, 7)) =  'NTLMSSP' then // no IdemPChar()
    begin
      if QuerySecurityPackageInfoW(SECPKGNAMENTLM, SecPkgInfo) <> 0 then
        raise ESynSspi.CreateLastOSError(aSecContext);
    end
    else
      if QuerySecurityPackageInfoW(SECPKGNAMENEGOTIATE, SecPkgInfo) <> 0 then
        raise ESynSspi.CreateLastOSError(aSecContext);
    try
      if AcquireCredentialsHandleW(nil, SecPkgInfo^.Name, SECPKG_CRED_INBOUND,
          nil, nil, nil, nil, @aSecContext.CredHandle, nil) <> 0 then
        raise ESynSspi.CreateLastOSError(aSecContext);
    finally
      FreeContextBuffer(SecPkgInfo);
    end;
    LInCtxPtr := nil;
  end
  else
    LInCtxPtr := @aSecContext.CtxHandle;
  OutBuf.BufferType := SECBUFFER_TOKEN;
  OutBuf.cbBuffer := 0;
  OutBuf.pvBuffer := nil;
  OutDesc.ulVersion := SECBUFFER_VERSION;
  OutDesc.cBuffers := 1;
  OutDesc.pBuffers := @OutBuf;
  Status := AcceptSecurityContext(@aSecContext.CredHandle, LInCtxPtr, @InDesc,
      ASC_REQ_ALLOCATE_MEMORY or ASC_REQ_CONFIDENTIALITY,
      SECURITY_NATIVE_DREP, @aSecContext.CtxHandle, @OutDesc, CtxAttr, nil);
  result := (Status = SEC_I_CONTINUE_NEEDED) or
            (Status = SEC_I_COMPLETE_AND_CONTINUE);
  if (Status = SEC_I_COMPLETE_NEEDED) or
     (Status = SEC_I_COMPLETE_AND_CONTINUE) then
    Status := CompleteAuthToken(@aSecContext.CtxHandle, @OutDesc);
  if Status < 0 then
      raise ESynSspi.CreateLastOSError(aSecContext);
  FastSetRawByteString(aOutData, OutBuf.pvBuffer, OutBuf.cbBuffer);
  FreeContextBuffer(OutBuf.pvBuffer);
end;

procedure ServerSspiAuthUser(var aSecContext: TSecContext;
  out aUserName: RawUtf8);
var
  Names: SecPkgContext_NamesW;
begin
  if QueryContextAttributesW(@aSecContext.CtxHandle,
       SECPKG_ATTR_NAMES, @Names) <> 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  Win32PWideCharToUtf8(Names.sUserName, StrLenW(Names.sUserName), aUserName);
  FreeContextBuffer(Names.sUserName);
end;

function SecPackageName(var aSecContext: TSecContext): RawUtf8;
var
  NegotiationInfo: TSecPkgContext_NegotiationInfo;
begin
  if QueryContextAttributesW(@aSecContext.CtxHandle,
       SECPKG_ATTR_NEGOTIATION_INFO, @NegotiationInfo) <> 0 then
    raise ESynSspi.CreateLastOSError(aSecContext);
  Win32PWideCharToUtf8(NegotiationInfo.PackageInfo^.Name,
               StrLenW(NegotiationInfo.PackageInfo^.Name), result);
  FreeContextBuffer(NegotiationInfo.PackageInfo);
end;

procedure ClientForceSpn(const aSecKerberosSpn: RawUtf8);
begin
  ForceSecKerberosSpn := SynUnicode(aSecKerberosSpn);
end;

var
  DomainAuthMode: (damUndefined, damNtlm, damNegotiate);

procedure SetDomainAuthMode;
begin
  if SspiForceNtlmClient then
  begin
    SECPKGNAMEHTTP := 'NTLM';
    DomainAuthMode := damNtlm;
  end
  else
  begin
    SECPKGNAMEHTTP := 'Negotiate';
    DomainAuthMode := damNegotiate;
  end;
  SECPKGNAMEHTTP_UPPER := UpperCaseU(SECPKGNAMEHTTP);
  SECPKGNAMEHTTPWWWAUTHENTICATE := 'WWW-Authenticate: ' + SECPKGNAMEHTTP;
  SECPKGNAMEHTTPAUTHORIZATION := 'AUTHORIZATION: ' + SECPKGNAMEHTTP_UPPER + ' ';
end;

function InitializeDomainAuth: boolean;
begin
  if (DomainAuthMode = damUndefined) or
     (SspiForceNtlmClient <> (DomainAuthMode = damNtlm)) then
    SetDomainAuthMode;
  result := true;
end;



{ ****************** Lan Manager Access Functions }

function NetApiBufferAllocate;    external netapi32;
function NetApiBufferFree;        external netapi32;
function NetApiBufferReallocate;  external netapi32;
function NetApiBufferSize;        external netapi32;

function NetUserAdd;              external netapi32;
function NetUserEnum;             external netapi32;
function NetUserGetInfo;          external netapi32;
function NetUserSetInfo;          external netapi32;
function NetUserDel;              external netapi32;
function NetUserGetGroups;        external netapi32;
function NetUserSetGroups;        external netapi32;
function NetUserGetLocalGroups;   external netapi32;
function NetUserModalsGet;        external netapi32;
function NetUserModalsSet;        external netapi32;
function NetUserChangePassword;   external netapi32;

function NetGroupEnum;            external netapi32;

function NetLocalGroupAdd;        external netapi32;
function NetLocalGroupAddMember;  external netapi32;
function NetLocalGroupEnum;       external netapi32;
function NetLocalGroupGetInfo;    external netapi32;
function NetLocalGroupSetInfo;    external netapi32;
function NetLocalGroupDel;        external netapi32;
function NetLocalGroupDelMember;  external netapi32;
function NetLocalGroupGetMembers; external netapi32;
function NetLocalGroupSetMembers; external netapi32;
function NetLocalGroupAddMembers; external netapi32;
function NetLocalGroupDelMembers; external netapi32;

procedure GetNames(g: PGroupInfo0Array; n: integer; var res: TRawUtf8DynArray);
var
  i: PtrInt;
begin
  if n > 0 then
  begin
    SetLength(res, n);
    for i := 0 to high(res) do
      Win32PWideCharToUtf8(g[i].name, StrLenW(g[i].name), res[i]);
  end;
  NetAPIBufferFree(g);
end;

function GetGroups(const server, user: RawUtf8; Local: boolean): TRawUtf8DynArray;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  s, u: PWideChar;
  res: integer;
  srv, usr: TSynTempBuffer;
begin
  result := nil;
  s := Utf8ToWin32PWideChar(server, srv);
  u := Utf8ToWin32PWideChar(user, usr);
  if Local then
    res := NetUserGetLocalGroups(s, u, 0, LG_INCLUDE_INDIRECT,
      v, MAX_PREFERRED_LENGTH, @dwEntriesRead, @dwEntriesTotal)
  else
    res := NetUserGetGroups(s, u, 0,
      v, MAX_PREFERRED_LENGTH, @dwEntriesRead, @dwEntriesTotal);
  if res = NERR_SUCCESS then
    GetNames(v, dwEntriesRead, result);
  srv.Done;
  usr.Done;
end;

function GetUsers(const server: RawUtf8;
  filter: TGetUsersFilterAccount): TRawUtf8DynArray;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  srv: TSynTempBuffer;
begin
  result := nil;
  if NetUserEnum(Utf8ToWin32PWideChar(server, srv), 0, byte(filter), v,
      MAX_PREFERRED_LENGTH, @dwEntriesRead, @dwEntriesTotal) = NERR_Success then
    // note: _USER_INFO_0 and _LOCALGROUP_INFO_0 are identical
    GetNames(v, dwEntriesRead, result);
  srv.Done;
end;

function GetGroups(const server: RawUtf8;
  sid: PRawUtf8DynArray; Local: boolean): TRawUtf8DynArray;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  s: PWideChar;
  g: PGroupInfo3;
  i: PtrInt;
  res: integer;
  srv: TSynTempBuffer;
begin
  result := nil;
  s := Utf8ToWin32PWideChar(server, srv);
  if (sid = nil) or
     Local then // NetLocalGroupEnum() does not support level 3 
  begin
    if Local then
      res := NetLocalGroupEnum(s, {level=}0, v, MAX_PREFERRED_LENGTH,
          @dwEntriesRead, @dwEntriesTotal)
    else
      res := NetGroupEnum(s, {level=}0, v, MAX_PREFERRED_LENGTH,
        @dwEntriesRead, @dwEntriesTotal);
    if res = NERR_Success then
      GetNames(v, dwEntriesRead, result);
  end
  else
  begin
    res := NetGroupEnum(s, {level=}3, v, MAX_PREFERRED_LENGTH,
              @dwEntriesRead, @dwEntriesTotal);
    if res = NERR_Success then // returns ERROR_INVALID_LEVEL if unsupported
    begin
      g := v;
      SetLength(result, dwEntriesRead);
      SetLength(sid^, dwEntriesRead);
      for i := 0 to integer(dwEntriesRead) - 1 do
      begin
        Win32PWideCharToUtf8(g^.name, StrLenW(g^.name), result[i]);
        sid^[i] := SidToText(g^.group_sid);
        inc(g);
      end;
      NetAPIBufferFree(v);
    end;
  end;
  srv.Done;
end;

function GetGroupSid(const Server, GroupName: RawUtf8; Local: boolean): RawUtf8;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  s: PWideChar;
  g: PGroupInfo3;
  res: integer;
  name: RawUtf8;
  srv: TSynTempBuffer;
begin
  result := '';
  if GroupName = '' then
    exit;
  s := Utf8ToWin32PWideChar(Server, srv);
  if Local then
    res := NetLocalGroupEnum(s, {level=}3, v, MAX_PREFERRED_LENGTH,
            @dwEntriesRead, @dwEntriesTotal)
  else
    res := NetGroupEnum(s, {level=}3, v, MAX_PREFERRED_LENGTH,
            @dwEntriesRead, @dwEntriesTotal);
  if res = NERR_Success then
  begin
    g := v;
    while dwEntriesRead <> 0 do
    begin
      Win32PWideCharToUtf8(g^.name, StrLenW(g^.name), Name);
      if PropNameEquals(Name, GroupName) then
      begin
        result := SidToText(g^.group_sid);
        break;
      end;
      inc(g);
      dec(dwEntriesRead);
    end;
    NetAPIBufferFree(v);
  end;
  srv.Done;
end;

function GetLocalGroups(const server: RawUtf8): TRawUtf8DynArray;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  srv: TSynTempBuffer;
begin
  result := nil;
  if NetLocalGroupEnum(Utf8ToWin32PWideChar(server, srv), 0, v,
      MAX_PREFERRED_LENGTH, @dwEntriesRead, @dwEntriesTotal) = NERR_Success then
    GetNames(v, dwEntriesRead, result);
  srv.Done;
end;

function GetLocalGroupMembers(const server, group: RawUtf8): TRawUtf8DynArray;
var
  dwEntriesRead, dwEntriesTotal: cardinal;
  v: pointer;
  s, g: PWideChar;
  srv, grp: TSynTempBuffer;
begin
  result := nil;
  s := Utf8ToWin32PWideChar(server, srv);
  g := Utf8ToWin32PWideChar(group, grp);
  if NetLocalGroupGetMembers(s, g, 3, v, MAX_PREFERRED_LENGTH,
      @dwEntriesRead, @dwEntriesTotal, nil) = NERR_Success then
    // note: _LOCALGROUP_MEMBERS_INFO_3 and _LOCALGROUP_INFO_0 are identical
    GetNames(v, dwEntriesRead, result);
  srv.Done;
  grp.Done;
end;

{$endif OSPOSIX}

end.

