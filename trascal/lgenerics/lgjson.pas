{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   JSON parser and utilites that try to follow RFC 8259.                   *
*                                                                           *
*   Copyright(c) 2020-2022 A.Koverdyaev(avk)                                *
*                                                                           *
*   This code is free software; you can redistribute it and/or modify it    *
*   under the terms of the Apache License, Version 2.0;                     *
*   You may obtain a copy of the License at                                 *
*     http://www.apache.org/licenses/LICENSE-2.0.                           *
*                                                                           *
*  Unless required by applicable law or agreed to in writing, software      *
*  distributed under the License is distributed on an "AS IS" BASIS,        *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
*  See the License for the specific language governing permissions and      *
*  limitations under the License.                                           *
*                                                                           *
*****************************************************************************}
unit lgJson;

{$MODE OBJFPC}{$H+}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}

interface

uses
  Classes, SysUtils, Math, BufStream,
  lgUtils,
  lgHelpers,
  lgAbstractContainer,
  lgArrayHelpers,
  lgQueue,
  lgVector,
  lgList,
  lgStack,
  lgSeqUtils,
  lgStrConst;

type
  TJsValueKind     = (jvkUnknown, jvkNull, jvkFalse, jvkTrue, jvkNumber, jvkString, jvkArray, jvkObject);
  TJsFormatOption  = (jfoSingleLine,      // the entire document on one line
                      jfoSingleLineArray, // each array on one line excluding the root
                      jfoSingleLineObject,// each object on one line excluding the root
                      jfoEgyptBrace,      // egyptian braces(default Allman)
                      jfoUseTabs,         // tabs instead of spaces.
                      jfoStrAsIs);        // do not encode Pascal strings as JSON strings
  TJsFormatOptions = set of TJsFormatOption;
  EJsException     = class(Exception);

  TJVarKind = (vkNull, vkBool, vkNumber, vkString);

  TJVariant = record
  strict private
  type
    TValue = record
      case Integer of
        0: (Num: Double);
        1: (Ref: Pointer);
        2: (Bool: Boolean);
        3: (Int: Int64);
    end;

  var
    FValue: TValue;
    FKind: TJVarKind;
    procedure DoClear; inline;
    procedure ConvertError(const aSrc, aDst: string);
  private
    class operator Initialize(var v: TJVariant);
    class operator Finalize(var v: TJVariant);
    class operator Copy(constref aSrc: TJVariant; var aDst: TJVariant); inline;
    class operator AddRef(var v: TJVariant);
  public
    class function Null: TJVariant; static; inline;
    class operator := (aValue: Double): TJVariant; inline;
    class operator := (aValue: Boolean): TJVariant; inline;
    class operator := (const aValue: string): TJVariant; inline;
    class operator := (const v: TJVariant): Double; inline;
    class operator := (const v: TJVariant): Int64; inline;
    class operator := (const v: TJVariant): Boolean; inline;
    class operator := (const v: TJVariant): string; inline;
    class operator = (const L, R: TJVariant): Boolean; inline;
    procedure Clear;
    procedure SetNull; inline;
    function  IsInteger: Boolean; inline;
  { returns a Boolean value of the instance; raises an exception if Kind <> vkBoolean }
    function  AsBoolean: Boolean; inline;
  { returns a numeric value of the instance; raises an exception if Kind <> vkNumber }
    function  AsNumber: Double; inline;
  { returns a integer value of the instance; raises an exception if Kind <> vkNumber
    or value is not exact integer }
    function  AsInteger: Int64; inline;
  { returns a string value of the instance; raises an exception if Kind <> vkString }
    function  AsString: string; inline;
  { returns a string representation of the instance }
    function  ToString: string; inline;
    property  Kind: TJVarKind read FKind;
  end;

  TJVarPair   = specialize TGMapEntry<string, TJVariant>;
  TJVarArray  = array of TJVariant;
  TJPairArray = array of TJVarPair;

function JNull: TJVariant; inline;
function JPair(const aName: string; const aValue: TJVariant): TJVarPair; inline;

type

  { TJsonPtr: wrapper over JSON Pointer(RFC 6901) functionality }
  TJsonPtr = record
  private
    FSegments: TStringArray;
    function GetCount: SizeInt; inline;
    function GetSegment(aIndex: SizeInt): string; inline;
    class function Encode(const aSegs: array of string): string; static;
    class function Decode(const s: string): TStringArray; static;
  public
  type
    TEnumerator = record
    private
      FList: TStringArray;
      FIndex: SizeInt;
      function GetCurrent: string; inline;
    public
      function MoveNext: Boolean; inline;
      property Current: string read GetCurrent;
    end;
  { checks if a Pascal string s is a well-formed JSON Pointer }
    class function ValidPtr(const s: string): Boolean; static;
  { checks if a JSON string s is a well-formed JSON Pointer }
    class function ValidAlien(const s: string): Boolean; static;
  { converts a JSON pointer instance aPtr into a sequence of segments;
    raises an EJsException if aPtr is not a well-formed JSON Pointer }
    class function ToSegments(const aPtr: string): TStringArray; static;
  { tres to convert a JSON pointer instance aPtr into a sequence of segments;
    returns False if aPtr is not a well-formed JSON Pointer }
    class function TryGetSegments(const aPtr: string; out aSegs: TStringArray): Boolean; static;
  { converts a sequence of segments into a JSON pointer }
    class function ToPointer(const aSegments: array of string): string; static;
    class operator = (const L, R: TJsonPtr): Boolean;
  { constructs a pointer from Pascal string, treats slash("/")
    as a path delimiter and "~" as a special character;
    use it only if the segments do not contain a slash or tilde;
    raises an EJsException if s is not a well-formed JSON Pointer }
    constructor From(const s: string);
  { constructs a pointer from path segments as Pascal strings }
    constructor From(const aPath: array of string);
  { constructs a pointer from JSON string, treats slash("/")
    as a path delimiter and "~" as a special character;
    raises an exception if s is not a well-formed JSON Pointer }
    constructor FromAlien(const s: string);
    function  GetEnumerator: TEnumerator; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure Clear; inline;
    procedure Append(const aSegment: string); inline;
  { returns a pointer as a Pascal string }
    function  ToString: string; inline;
  { returns a pointer as a JSON string }
    function  ToAlien: string;
    function  ToSegments: TStringArray; inline;
    property  Count: SizeInt read GetCount;
    property  Segments[aIndex: SizeInt]: string read GetSegment; default;
  end;

const
  DEF_INDENT = 4;

type
  { TJsonNode is the entity used to validate, parse, generate, and navigate a json document;
    the lifetime of all nested elements is determined by the document root node;
    it is this (and only this) node that requires explicit free;
    the current implementation preserves the ordering of elements in objects;
    validator and parser are based on Douglas Crockford's JSON_checker code }
  TJsonNode = class
  public
  const
    DEF_DEPTH = 511;

  type
    TPair           = specialize TGMapEntry<string, TJsonNode>;
    TNodeArray      = array of TJsonNode;
    IPairEnumerable = specialize IGEnumerable<TPair>;

    TIterContext = record
      Level,
      Index: SizeInt;
      Name: string;
      Parent: TJsonNode;
      constructor Init(aLevel, aIndex: SizeInt; aParent: TJsonNode);
      constructor Init(aLevel: SizeInt; const aName: string; aParent: TJsonNode);
      constructor Init(aParent: TJsonNode);
    end;

    TOnIterate   = function(const aContext: TIterContext; aNode: TJsonNode): Boolean of object;
    TNestIterate = function(const aContext: TIterContext; aNode: TJsonNode): Boolean is nested;

    TVisitNode = record
      Level,
      Index: SizeInt;
      Name: string;
      Parent,
      Node: TJsonNode;
      constructor Init(aLevel, aIndex: SizeInt; aParent, aNode: TJsonNode);
      constructor Init(aLevel: SizeInt; const aName: string; aParent, aNode: TJsonNode);
      constructor Init(aNode: TJsonNode);
    end;

    INodeEnumerable = specialize IGEnumerable<TVisitNode>;

  private
  const
    S_BUILD_INIT_SIZE = 256;
    RW_BUF_SIZE       = 65536;

  type
    TStrBuilder = record
    private
      FBuffer: array of AnsiChar;
      FCount: SizeInt;
    public
      constructor Create(aCapacity: SizeInt);
      constructor Create(const s: string);
      function  IsEmpty: Boolean; inline;
      function  NonEmpty: Boolean; inline;
      procedure MakeEmpty; inline;
      procedure EnsureCapacity(aCapacity: SizeInt); inline;
      procedure Append(c: AnsiChar); inline;
      procedure Append(c: AnsiChar; aCount: SizeInt);
      procedure Append(const s: string); inline;
      procedure AppendEncode(const s: string);
      procedure Append(const s: shortstring); inline;
      function  SaveToStream(aStream: TStream): SizeInt; inline;
      function  ToString: string; inline;
      function  ToDecodeString: string;
      function  ToPChar: PAnsiChar; inline;
      property  Count: SizeInt read FCount;
    end;

    TJsArray        = specialize TGLiteVector<TJsonNode>;
    TJsObject       = specialize TGLiteHashList2<string, TPair, string>;
    PJsArray        = ^TJsArray;
    PJsObject       = ^TJsObject;
    TPairEnumerator = specialize TGEnumerator<TPair>;
    TPairs          = specialize TGEnumCursor<TPair>;
    TRwBuffer       = array[0..Pred(RW_BUF_SIZE div SizeOf(SizeUInt))] of SizeUInt;

    TEmptyPairEnumerator = class(TPairEnumerator)
    protected
      function  GetCurrent: TPair; override;
    public
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TEqualEnumerator = class(TPairEnumerator)
    protected
      FEnum: TJsObject.TEqualEnumerator;
      function  GetCurrent: TPair; override;
    public
      constructor Create(const aEnum: TJsObject.TEqualEnumerator);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TValue = record
    case Integer of
      0: (Ref: Pointer);
      1: (Num: Double);
      2: (Int: Int64);
    end;

  var
    FValue: TValue;
    FKind: TJsValueKind;
    class function  CreateJsArray: PJsArray; static; inline;
    class procedure FreeJsArray(a: PJsArray); static;
    class function  CreateJsObject: PJsObject; static; inline;
    class procedure FreeJsObject(o: PJsObject); static;
    function  GetFString: string; inline;
    function  GetFArray: PJsArray; inline;
    function  GetFObject: PJsObject; inline;
    procedure SetFString(const aValue: string); inline;
    procedure SetFArray(aValue: PJsArray); inline;
    procedure SetFObject(aValue: PJsObject); inline;
    procedure DoClear;
    function  GetAsArray: TJsonNode; inline;
    function  GetAsObject: TJsonNode; inline;
    function  GetAsNull: TJsonNode; inline;
    function  GetAsBoolean: Boolean; inline;
    procedure SetAsBoolean(aValue: Boolean); inline;
    function  GetAsNumber: Double; inline;
    procedure SetAsNumber(aValue: Double);
    function  GetAsString: string; inline;
    procedure SetAsString(const aValue: string); inline;
    function  DoBuildJson: TStrBuilder;
    function  GetAsJson: string; inline;
    procedure SetAsJson(const aValue: string);
    function  GetCount: SizeInt; inline;
    function  CanArrayInsert(aIndex: SizeInt): Boolean; inline;
    function  CanObjectInsert(aIndex: SizeInt): Boolean; inline;
    function  GetItem(aIndex: SizeInt): TJsonNode;
    function  GetPair(aIndex: SizeInt): TPair;
    function  GetByName(const aName: string): TJsonNode;
    function  GetValue(const aName: string): TJVariant;
    procedure SetValue(const aName: string; const aValue: TJVariant);
    procedure SetNArray(const aName: string; const aValue: TJVarArray);
    procedure SetNObject(const aName: string; const aValue: TJPairArray);
    property  FString: string read GetFString write SetFString;
    property  FArray: PJsArray read GetFArray write SetFArray;
    property  FObject: PJsObject read GetFObject write SetFObject;

  type
    TNodeEnumerator = class(specialize TGEnumerator<TVisitNode>)
    private
    type
      TQueue = specialize TGLiteQueue<TVisitNode>;
    var
      FQueue: TQueue;
      FStart,
      FCurrent: TVisitNode;
    protected
      function  GetCurrent: TVisitNode; override;
    public
      constructor Create(aNode: TJsonNode);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

  private
     function GetNodeEnumerable: INodeEnumerable;
  public
  type
    TEnumerator = record
    private
      FNode: TJsonNode;
      FCurrIndex: SizeInt;
      function GetCurrent: TJsonNode; inline;
    public
      function MoveNext: Boolean; inline;
      property Current: TJsonNode read GetCurrent;
    end;

    TTreeEnumerator = record
    private
    type
      TQueue = specialize TGLiteQueue<TJsonNode>;
    var
      FQueue: TQueue;
      FCurrent: TJsonNode;
      function GetCurrent: TJsonNode; inline;
    public
      function MoveNext: Boolean;
      property Current: TJsonNode read GetCurrent;
    end;

    TSubTree = record
    private
      FNode: TJsonNode;
    public
      function GetEnumerator: TTreeEnumerator;
    end;

    TEntryEnumerator = record
    private
      FNode: TJsonNode;
      FCurrIndex: SizeInt;
      function GetCurrent: TPair; inline;
    public
      function MoveNext: Boolean; inline;
      property Current: TPair read GetCurrent;
    end;

    TEntries = record
    private
      FNode: TJsonNode;
    public
      function GetEnumerator: TEntryEnumerator;
    end;

    TNameEnumerator = record
    private
      FNode: TJsonNode;
      FCurrIndex: SizeInt;
      function GetCurrent: string; inline;
    public
      function MoveNext: Boolean; inline;
      property Current: string read GetCurrent;
    end;

    TNames = record
    private
      FNode: TJsonNode;
    public
      function GetEnumerator: TNameEnumerator;
    end;

  { checks if the content is well-formed JSON; aDepth indicates the maximum allowable
    nesting depth of structures; if aSkipBom is set to True then UTF-8 BOM(and only that)
    will be ignored }
    class function ValidJson(const s: string; aDepth: Integer = DEF_DEPTH;
                             aSkipBom: Boolean = False): Boolean; static;
    class function ValidJson(aStream: TStream; aDepth: Integer = DEF_DEPTH;
                             aSkipBom: Boolean = False): Boolean; static;
    class function ValidJson(aStream: TStream; aCount: SizeInt; aDepth: Integer = DEF_DEPTH;
                             aSkipBom: Boolean = False): Boolean; static;
    class function ValidJsonFile(const aFileName: string; aDepth: Integer = DEF_DEPTH;
                                 aSkipBom: Boolean = False): Boolean; static;
  { checks if s represents a valid JSON string }
    class function JsonStringValid(const s: string): Boolean; static;
  { checks if s represents a valid JSON number }
    class function JsonNumberValid(const s: string): Boolean; static;
    class function LikelyKind(aBuf: PAnsiChar; aSize: SizeInt): TJsValueKind; static;
  { returns the parsing result; if the result is True, then the created
    object is returned in the aRoot parameter, otherwise nil is returned }
    class function TryParse(const s: string; out aRoot: TJsonNode;
                            aDepth: Integer = DEF_DEPTH; aSkipBom: Boolean = False): Boolean; static;
    class function TryParse(aStream: TStream; out aRoot: TJsonNode;
                            aDepth: Integer = DEF_DEPTH; aSkipBom: Boolean = False): Boolean; static;
    class function TryParse(aStream: TStream; aCount: SizeInt; out aRoot: TJsonNode;
                            aDepth: Integer = DEF_DEPTH; aSkipBom: Boolean = False): Boolean; static;
  { note: the responsibility for the existence of the file lies with the user }
    class function TryParseFile(const aFileName: string; out aRoot: TJsonNode;
                            aDepth: Integer = DEF_DEPTH; aSkipBom: Boolean = False): Boolean; static;
  { returns the document root node if parsing is successful, nil otherwise }
    class function Load(const s: string; aDepth: Integer = DEF_DEPTH;
                        aSkipBom: Boolean = False): TJsonNode; static;
    class function Load(aStream: TStream; aDepth: Integer = DEF_DEPTH;
                        aSkipBom: Boolean = False): TJsonNode; static;
    class function Load(aStream: TStream; aCount: SizeInt; aDepth: Integer = DEF_DEPTH;
                        aSkipBom: Boolean = False): TJsonNode; static;
  { note: the responsibility for the existence of the file lies with the user }
    class function LoadFromFile(const aFileName: string; aDepth: Integer = DEF_DEPTH;
                               aSkipBom: Boolean = False): TJsonNode; static;
  { converts a pascal string to a JSON string }
    class function PasStrToJson(const s: string): string; static;
    class function NewNode: TJsonNode; static; inline;
    class function NewNull: TJsonNode; static; inline;
    class function NewNode(aValue: Boolean): TJsonNode; static; inline;
    class function NewNode(aValue: Double): TJsonNode; static; inline;
    class function NewNode(const aValue: string): TJsonNode; static; inline;
    class function NewNode(aKind: TJsValueKind): TJsonNode; static; inline;
    class function NewNode(aNode: TJsonNode): TJsonNode; static; inline;
  { returns the document root node if parsing is successful, nil otherwise }
    class function NewJson(const s: string): TJsonNode; static; inline;
  { returns the maximum nesting depth of aNode, is recursive }
    class function MaxNestDepth(aNode: TJsonNode): SizeInt; static;
  { returns True if aNode has no non-unique names, is recursive }
    class function DupeNamesFree(aNode: TJsonNode): Boolean; static;
    class function Equal(L, R: TJsonNode): Boolean; static;
    class function HashCode(aNode: TJsonNode): SizeInt; static;
    constructor Create;
    constructor CreateNull;
    constructor Create(aValue: Boolean);
    constructor Create(aValue: Double);
    constructor Create(const aValue: string);
    constructor Create(aKind: TJsValueKind);
    constructor Create(const a: TJVarArray);
    constructor Create(const a: TJPairArray);
    constructor Create(aNode: TJsonNode);
    destructor Destroy; override;
    function  GetEnumerator: TEnumerator; inline;
    function  SubTree: TSubTree; inline;
    function  Enrties: TEntries; inline;
    function  Names: TNames; inline;
    function  EqualNames(const aName: string): IPairEnumerable; inline;
    function  IsNull: Boolean; inline;
    function  IsFalse: Boolean; inline;
    function  IsTrue: Boolean; inline;
    function  IsNumber: Boolean; inline;
    function  IsInteger: Boolean; inline;
    function  IsString: Boolean; inline;
    function  IsArray: Boolean; inline;
    function  IsObject: Boolean; inline;
    function  IsBoolean: Boolean; inline;
    function  IsLiteral: Boolean; inline;
    function  IsScalar: Boolean; inline;
    function  IsStruct: Boolean; inline;
    procedure Clear; inline;
  { duplicates an instance, is recursive }
    function  Clone: TJsonNode;
  { makes a deep copy of the aNode, does not check if aNode is assigned, is recursive }
    procedure CopyFrom(aNode: TJsonNode);
  { checks that an instance is element-wise equal to aNode, is recursive;
    returns false if any object contains a non-unique key }
    function  EqualTo(aNode: TJsonNode): Boolean;
    function  HashCode: SizeInt;
  { tries to load JSON from a string, in case of failure it returns False,
    in this case the content of the instance does not change }
    function  Parse(const s: string): Boolean;
  { Recursively traverses the document tree in a Preorder manner, calling aFunc on each node;
    exits immediately if aFunc returns False }
    procedure Iterate(aFunc: TOnIterate);
    procedure Iterate(aFunc: TNestIterate);
  { adds null to the instance as to an array; if it is not an array,
    it is cleared and becomes an array - be careful; returns Self }
    function  AddNull: TJsonNode; inline;
  { adds Boolean value to the instance as to an array; if it is not
    an array, it is cleared and becomes an array - be careful; returns Self }
    function  Add(aValue: Boolean): TJsonNode; inline;
  { adds a number to the instance as to an array; if it is not an array,
    it is cleared and becomes an array - be careful; returns Self }
    function  Add(aValue: Double): TJsonNode; inline;
  { adds string value to the instance as to an array; if it is not an array,
    it is cleared and becomes an array - be careful; returns Self }
    function  Add(const aValue: string): TJsonNode; inline;
  { adds a new array from the elements of the array a to the instance as to an array;
    if it is not an array, it is cleared and becomes an array - be careful; returns Self }
    function  Add(const a: TJVarArray): TJsonNode;
  { adds a new object from the elements of the array a to the instance as to an array;
    if it is not an array, it is cleared and becomes an array - be careful; returns Self }
    function  Add(const a: TJPairArray): TJsonNode;
  { adds a new object of the specified kind to the instance as to an array;
    if an instance is not an array, it is cleared and becomes an array - be careful;
    returns a new object }
    function  AddNode(aKind: TJsValueKind = jvkUnknown): TJsonNode; //inline;
  { returns True and the created object in the aNode parameter,
    if the string s can be parsed; the new object is added as in an array - be careful }
    function  AddJson(const s: string; out aNode: TJsonNode): Boolean;
  { adds all elements from aNode to the instance as to an array;
    if it is not an array, it is cleared and becomes an array - be careful;
    if aNode is a structure it becomes empty; returns Self }
    function  Append(aNode: TJsonNode): TJsonNode;
  { adds pair aName: null to the instance as to an object; if it is not an object,
    it is cleared and becomes an object - be careful; returns Self }
    function  AddNull(const aName: string): TJsonNode; inline;
  { adds pair (aName: aValue) to the instance as to an object; if it is not an object,
    it is cleared and becomes an object - be careful; returns Self }
    function  Add(const aName: string; aValue: Boolean): TJsonNode; inline;
    function  Add(const aName: string; aValue: Double): TJsonNode; inline;
    function  Add(const aName, aValue: string): TJsonNode; inline;
  { adds pair (aName: array from aValue elements) to the instance as to an object;
    if it is not an object, it is cleared and becomes an object - be careful; returns Self }
    function  Add(const aName: string; const aValue: TJVarArray): TJsonNode;
  { adds pair (aName: object from aValue elements) to the instance as to an object;
    if it is not an object, it is cleared and becomes an object - be careful; returns Self }
    function  Add(const aName: string; const aValue: TJPairArray): TJsonNode;
  { adds a new object of the specified type associated with aName to the instance as to an object;
    if an instance is not an object, it is cleared and becomes an object - be careful;
    returns a new object }
    function  AddNode(const aName: string; aKind: TJsValueKind = jvkUnknown): TJsonNode; //inline;
  { returns True and the created object associated with aName in the aNode parameter,
    if the string aJson can be parsed; the new object is added as to an object - be careful }
    function  AddJson(const aName, aJson: string; out aNode: TJsonNode): Boolean;
  { adds pair (aName: null) to the instance as to an object and returns True
    only if aName is unique within an instance, otherwise returns False;
    if an instance is not an object, it is cleared and becomes an object - be careful }
    function  AddUniqNull(const aName: string): Boolean;
  { adds pair (aName: aValue) to the instance as to an object and returns True
    only if aName is unique within an instance, otherwise returns False;
    if an instance is not an object, it is cleared and becomes an object - be careful }
    function  AddUniq(const aName: string; aValue: Boolean): Boolean;
    function  AddUniq(const aName: string; aValue: Double): Boolean;
    function  AddUniq(const aName, aValue: string): Boolean;
    function  AddUniq(const aName: string; const aValue: TJVarArray): Boolean;
    function  AddUniq(const aName: string; const aValue: TJPairArray): Boolean;
  { adds a new object of the specified type associated with aName to the instance as to an object
    only if aName is unique within an instance, otherwise returns False;
    if an instance is not an object, it is cleared and becomes an object - be careful;
    returns a new object }
    function  AddUniqNode(const aName: string; out aNode: TJsonNode; aKind: TJsValueKind): Boolean;
  { returns True and the created object associated with aName in the aNode parameter,
    only if aName is unique within an instance and the string aJson can be parsed;
    the new object is added as in an object - be careful }
    function  AddUniqJson(const aName, aJson: string; out aNode: TJsonNode): Boolean;
  { if aIndex = 0 then acts like AddNull;
    returns True and inserts null at position aIndex if aIndex is in the range [1..Count]
    and the instance is an array, otherwise it returns False }
    function  InsertNull(aIndex: SizeInt): Boolean;
  { if aIndex = 0 then acts like Add(aValue);
    returns True and inserts aValue at position aIndex if aIndex is in the range [1..Count]
    and the instance is an array, otherwise it returns False}
    function  Insert(aIndex: SizeInt; aValue: Boolean): Boolean;
    function  Insert(aIndex: SizeInt; aValue: Double): Boolean;
    function  Insert(aIndex: SizeInt; const aValue: string): Boolean;
  { if aIndex = 0 then acts like AddNode;
    returns True and inserts new object(aNode) of the specified kind
    at position aIndex if aIndex is in the range [1..Count]
    and the instance is an array, otherwise it returns False }
    function  InsertNode(aIndex: SizeInt; out aNode: TJsonNode; aKind: TJsValueKind): Boolean;
  { }
    function  InsertNull(aIndex: SizeInt; const aName: string): Boolean;
    function  Insert(aIndex: SizeInt; const aName: string; aValue: Boolean): Boolean;
    function  Insert(aIndex: SizeInt; const aName: string; aValue: Double): Boolean;
    function  Insert(aIndex: SizeInt; const aName, aValue: string): Boolean;
    function  InsertNode(aIndex: SizeInt; const aName: string; out aNode: TJsonNode; aKind: TJsValueKind): Boolean;
    function  Contains(const aName: string): Boolean; inline;
    function  ContainsUniq(const aName: string): Boolean; inline;
    function  IndexOfName(const aName: string): SizeInt; inline;
    function  CountOfName(const aName: string): SizeInt; inline;
    function  HasUniqName(aIndex: SizeInt): Boolean; inline;
    function  Find(const aKey: string; out aValue: TJsonNode): Boolean;
  { returns True if aName is found, otherwise adds a new pair with
    Value.Kind = jvkUnknown and returns False;
    if the instance is not an object, it is cleared and becomes an object - be careful }
    function  FindOrAdd(const aName: string; out aValue: TJsonNode): Boolean;
    function  FindUniq(const aName: string; out aValue: TJsonNode): Boolean;
    function  FindAll(const aName: string): TNodeArray;
    function  Find(aIndex: SizeInt; out aValue: TJsonNode): Boolean;
    function  FindPair(aIndex: SizeInt; out aValue: TPair): Boolean;
    function  FindName(aIndex: SizeInt; out aName: string): Boolean;
    function  Delete(aIndex: SizeInt): Boolean;
    function  Extract(aIndex: SizeInt; out aNode: TJsonNode): Boolean;
    function  Extract(aIndex: SizeInt; out aPair: TPair): Boolean;
    function  Extract(const aName: string; out aNode: TJsonNode): Boolean;
    function  Remove(const aName: string): Boolean;
    function  RemoveAll(const aName: string): SizeInt;
  { tries to find an element using a path specified as an array of path segments;
    if non-unique keys are encountered in the search path, the search terminates
    immediately and returns False; the "-" element has a special sense only if it is
    the last segment of the path, otherwise it is treated as a string;
    each node considered self as a root }
    function  FindPath(const aPath: array of string; out aNode: TJsonNode): Boolean;
    function  FindPath(const aPath: array of string): TJsonNode;
  { tries to find an element using a path specified as a JSON Pointer wrapper;
    if non-unique keys are encountered in the search path, the search terminates
    immediately and returns False; the "-" element has a special sense only if it is
    the last segment of the path, otherwise it is treated as a string;
    each node considered self as a root; }
    function  FindPath(const aPtr: TJsonPtr; out aNode: TJsonNode): Boolean;
    function  FindPath(const aPtr: TJsonPtr): TJsonNode; inline;
  { tries to find the element using the path given by the JSON pointer as a Pascal string }
    function  FindPathPtr(const aPtr: string; out aNode: TJsonNode): Boolean;
    function  FindPathPtr(const aPtr: string): TJsonNode; inline;
  { returns a formatted JSON representation of an instance, is recursive }
    function  FormatJson(aOptions: TJsFormatOptions = []; aIndentSize: Integer = DEF_INDENT;
                         aOffset: Integer = 0): string;
    function  GetValue(out aValue: TJVariant): Boolean;
  { returns the number of bytes written }
    function  SaveToStream(aStream: TStream): SizeInt; inline;
    procedure SaveToFile(const aFileName: string);
    function  ToString: string; override;
  { GetAsJson returns the most compact JSON representation of an instance, is recursive;
    SetAsJson remark: if the parser fails to parse the original string,
    an exception will be raised. }
    property  AsJson: string read GetAsJson write SetAsJson;
  { converts an instance to null }
    property  AsNull: TJsonNode read GetAsNull;
  { converts an instance to a Boolean }
    property  AsBoolean: Boolean read GetAsBoolean write SetAsBoolean;
  { converts an instance to a number }
    property  AsNumber: Double read GetAsNumber write SetAsNumber;
  { converts an instance to a string }
    property  AsString: string read GetAsString write SetAsString;
  { converts an instance to an array }
    property  AsArray: TJsonNode read GetAsArray;
  { converts an instance to an object }
    property  AsObject: TJsonNode read GetAsObject;
  { traverses the document tree in BFS manner, level by level }
    property  AsEnumerable: INodeEnumerable read GetNodeEnumerable;
    property  Kind: TJsValueKind read FKind;
    property  Count: SizeInt read GetCount;
  { will raise exception if aIndex out of bounds }
    property  Items[aIndex: SizeInt]: TJsonNode read GetItem;
  { will raise exception if aIndex out of bounds or an instance is not an object }
    property  Pairs[aIndex: SizeInt]: TPair read GetPair;
  { acts as FindOrAdd }
    property  NItems[const aName: string]: TJsonNode read GetByName; //todo: need another prop name?
  { if GetValue does not find aName or if the value found is an array or object,
    it will raise an exception; SetValue will make an object from an instance - be careful }
    property  Values[const aName: string]: TJVariant read GetValue write SetValue; default;
  { will make an object from an instance }
    property  NArrays[const aName: string]: TJVarArray write SetNArray;
  { will make an object from an instance }
    property  NObjects[const aName: string]: TJPairArray write SetNObject;
  end;

  TPatchResult = (prOk, prPatchMiss, prTargetMiss, prMalformPatch, prFail);
  TDiffResult  = (drOk, drSourceMiss, drTargetMiss, drFail);

  TDiffOption  = (
    doEmitTestOnRemove,   { generate test operations that check that the target's values to be
                            removed are exactly equal to the expected ones }

    doEmitTestOnReplace,  { generate test operations that check that the target's values to be
                            replaced are exactly equal to the expected ones }

    doDisableArrayReplace,//leave only deletions and insertions available in arrays

    doEnableMove          { replace successive ADD/REMOVE (or vice versa) operations applied
                            to the same value with a single MOVE operation }
    );
  TDiffOptions = set of TDiffOption;

  { TJsonPatch provides support for JSON Patch(RFC 6902, see also http://jsonpatch.com/);
    JSON Patch is a format for expressing a sequence of operations to apply to
    a target JSON document, it supports ADD, REMOVE, REPLACE, MOVE, COPY, and TEST
    operations; in the current implementation, the application of the patch tries to be
    atomic, that is, if any error occurs, the contents of the target does not change }
  TJsonPatch = class
  private
  type
    TStrHelper = specialize TGSimpleArrayHelper<string>;
    TStrUtil   = specialize TGSeqUtil<string, string>;
    TStrVector = specialize TGLiteVector<string>;
    TDiffUtil  = specialize TGSeqUtil<TJsonNode, TJsonNode>;

  const
    OP_KEY      = 'op';
    VAL_KEY     = 'value';
    PATH_KEY    = 'path';
    FROM_KEY    = 'from';
    ADD_KEY     = 'add';
    COPY_KEY    = 'copy';
    MOVE_KEY    = 'move';
    REMOVE_KEY  = 'remove';
    REPLACE_KEY = 'replace';
    TEST_KEY    = 'test';
  private
    FNode: TJsonNode;
    FLoaded,
    FValidated: Boolean;
    class function  FindOp(aNode: TJsonNode; var aOpNode: TJsonNode): Boolean; static; inline;
    class function  TestPathValue(aNode: TJsonNode): Boolean; static; inline;
    class function  TestPath(aNode: TJsonNode): Boolean; static; inline;
    class function  TestMovePaths(aNode: TJsonNode): Boolean; static; inline;
    class function  TestCopyPaths(aNode: TJsonNode): Boolean; static; inline;
    class function  GetValAndPath(aNode: TJsonNode; var aValNode: TJsonNode;
                                  out aPath: TStringArray): Boolean; static; inline;
    class function  GetMovePaths(aNode: TJsonNode; var aPathNode: TJsonNode;
                                 out aFrom, aTo: TStringArray): Boolean; static;
    class function  GetCopyPaths(aNode: TJsonNode; var aPathNode: TJsonNode;
                                 out aFrom, aTo: TStringArray): Boolean; static;
    class function  GetPath(aNode: TJsonNode; var aPathNode: TJsonNode; out aPath: TStringArray): Boolean; static;
    class function  FindExistStruct(aNode: TJsonNode; const aPath: TStringArray; out aStruct: TJsonNode;
                                    out aStructKey: string): Boolean; static; inline;
    class procedure MoveNode(aSrc, aDst: TJsonNode); static; inline;
    class function  FindCopyValue(aNode: TJsonNode; const aPath: TStringArray; out aValue: TJsonNode): Boolean; static;
    class function  TryAdd(aNode, aValue: TJsonNode; const aPath: TStringArray): Boolean; static;
    class function  TryRemove(aNode: TJsonNode; const aPath: TStringArray): Boolean; static;
    class function  TryExtract(aNode: TJsonNode; const aPath: TStringArray; out aValue: TJsonNode): Boolean; static;
    class function  TryMove(aNode, aValue: TJsonNode; const aPath: TStringArray): Boolean; static;
    class function  TryReplace(aNode, aValue: TJsonNode; const aPath: TStringArray): Boolean; static;
    class function  TryTest(aNode, aValue: TJsonNode; const aPath: TStringArray): Boolean; static;
    function GetAsJson: string;
    function SeemsValidPatch(aNode: TJsonNode): Boolean;
    function ApplyValidated(aNode: TJsonNode): TPatchResult;
  public
  const
    MIME_TYPE = 'application/json-patch+json';
    DEF_DEPTH = TJsonNode.DEF_DEPTH;
  { creates a patch that converts aSource to aTarget  }
    class function Diff(aSource, aTarget: TJsonNode; out aDiff: TJsonNode;
                        aOptions: TDiffOptions = []): TDiffResult; static;
    class function Diff(aSource, aTarget: TJsonNode; out aDiff: TJsonPatch;
                        aOptions: TDiffOptions = []): TDiffResult; static;
    class function Diff(aSource, aTarget: TJsonNode; out aDiff: string;
                        aOptions: TDiffOptions = []): TDiffResult; static;
    class function Diff(const aSource, aTarget: string; out aDiff: TJsonNode;
                        aOptions: TDiffOptions = []): TDiffResult; static;
    class function Diff(const aSource, aTarget: string; out aDiff: TJsonPatch;
                        aOptions: TDiffOptions = []): TDiffResult; static;
    class function Diff(const aSource, aTarget: string; out aDiff: string;
                        aOptions: TDiffOptions = []): TDiffResult; static;
  { tries to load a patch content from s, returns False if s is malformed JSON }
    class function TryLoadPatch(const s: string; out p: TJsonPatch): Boolean; static;
  { returns TJsonPatch instance if s is well-formed JSON, otherwise returns NIL }
    class function LoadPatch(const s: string): TJsonPatch; static; inline;
  { tries to load a patch content from file, returns False if file contains malformed JSON;
    note: the responsibility for the existence of the file lies with the user }
    class function TryLoadPatchFile(const aFileName: string; out p: TJsonPatch): Boolean; static;
  { returns TJsonPatch instance if file contains well-formed JSON, otherwise returns NIL;
    note: the responsibility for the existence of the file lies with the user }
    class function LoadPatchFile(const aFileName: string): TJsonPatch; static; inline;
  { returns the result of applying the content of p to a JSON document given as a string aTarget;
    on any result other than prOk, the contents of the aTarget does not change }
    class function Patch(p: TJsonPatch; var aTarget: string): TPatchResult; static; inline;
  { returns the result of applying the content of p to a JSON document given as a string aTarget }
    class function Patch(p: TJsonNode; var aTarget: string): TPatchResult;
  { returns the result of applying a patch given as a string aPatch, to a JSON document
    given as a string aTarget;
    on any result other than prOk, the contents of the aTarget does not change }
    class function Patch(const aPatch: string; var aTarget: string): TPatchResult; static;
    class function Patch(const aPatch: string; aTarget: TJsonNode): TPatchResult; static;
  { returns the result of applying the content of P to the JSON document contained in the file;
    on any result other than prOk, the contents of the file does not change;
    note: the responsibility for the existence of the file lies with the user }
    class function PatchFile(p: TJsonPatch; const aTargetFileName: string): TPatchResult; static;
  { returns the result of applying a patch given as a string aPatch, to a JSON document
    contained in the file;
    on any result other than prOk, the contents of the file does not change;
    note: the responsibility for the existence of the file lies with the user }
    class function PatchFile(const aPatch: string; const aTargetFileName: string): TPatchResult; static;

    destructor Destroy; override;
    procedure Clear; inline;
  { tries to load content from s, returns False if s is malformed JSON }
    function  TryLoad(const s: string): Boolean;
    function  TryLoad(aStream: TStream; aCount: SizeInt): Boolean;
  { tries to load content from file, returns False if file contains malformed JSON;
    note: the responsibility for the existence of the file lies with the user }
    function  TryLoadFile(const aFileName: string): Boolean;
    procedure Load(aNode: TJsonNode);
  { returns True if the content looks like a JSON patch }
    function  Validate: Boolean; inline;
  { returns the result of applying the content to the aTarget; any operation will fail
    if the search path contains keys that are not unique within the corresponding object;
    on any result other than prOk, the contents of the aTarget does not change }
    function  Apply(aTarget: TJsonNode): TPatchResult;
    function  Apply(var aTarget: string): TPatchResult;
    function  TryAsJson(out aJson: string): Boolean;
    property  Loaded: Boolean read FLoaded;
    property  Validated: Boolean read FValidated;
    property  AsJson: string read GetAsJson;
  end;

  { TJsonWriter provides a quick way of producing JSON document;
    no whitespace is added, so the results is presented in the most compact form;
    you yourself are responsible for the syntactic correctness of the generated document;
    each instance of TJsonWriter can produce one JSON document }
  TJsonWriter = class
  private
    FStream: TWriteBufStream;
    FStack: specialize TGLiteStack<Integer>;
    FsBuilder: TJsonNode.TStrBuilder;
    procedure ValueAdding; inline;
    procedure PairAdding; inline;
  public
    class function New(aStream: TStream): TJsonWriter; static; inline;
  { returns the number of bytes written }
    class function WriteJson(aStream: TStream; aNode: TJsonNode): SizeInt; static;
    constructor Create(aStream: TStream);
    destructor Destroy; override;
    function AddNull: TJsonWriter;
    function AddFalse: TJsonWriter;
    function AddTrue: TJsonWriter;
    function Add(aValue: Double): TJsonWriter;
    function Add(const s: string): TJsonWriter;
    function Add(aValue: TJsonNode): TJsonWriter; inline;
    function AddJson(const aJson: string): TJsonWriter;
    function AddName(const aName: string): TJsonWriter;
    function AddNull(const aName: string): TJsonWriter;
    function AddFalse(const aName: string): TJsonWriter;
    function AddTrue(const aName: string): TJsonWriter;
    function Add(const aName: string; aValue: Double): TJsonWriter;
    function Add(const aName, aValue: string): TJsonWriter;
    function Add(const aName: string; aValue: TJsonNode): TJsonWriter; inline;
    function AddJson(const aName, aJson: string): TJsonWriter;
    function BeginArray: TJsonWriter;
    function BeginObject: TJsonWriter;
    function EndArray: TJsonWriter;
    function EndObject: TJsonWriter;
  end;

  TParseMode = (pmNone, pmKey, pmArray, pmObject);
  PParseMode = ^TParseMode;

  { TJsonReader provides forward only navigation through the JSON stream
    with ability to skip some parts of the document; also has the ability
    to find specific place in JSON by a path from the document root }
  TJsonReader = class
  public
  const
    DEF_DEPTH = 511;
  type
    TOnIterate   = function(aIter: TJsonReader): Boolean of object;
    TNestIterate = function(aIter: TJsonReader): Boolean is nested;

    TReadState = (rsStart, rsGo, rsEOF, rsError);

    TTokenKind = (
      tkNone,
      tkNull,
      tkFalse,
      tkTrue,
      tkNumber,
      tkString,
      tkArrayBegin,
      tkObjectBegin,
      tkArrayEnd,
      tkObjectEnd);

    TStructKind = (skNone, skArray, skObject);
  private
  type
    TLevel = record
      Mode: TParseMode;
      Path: string;
      CurrIndex: SizeInt;
      constructor Create(aMode: TParseMode);
      constructor Create(aMode: TParseMode; aPath: string);
      constructor Create(aMode: TParseMode; aIndex: SizeInt);
    end;

  var
    FBuffer: PAnsiChar;
    FStack: array of TLevel;
    FsBuilder,
    FsbHelp: TJsonNode.TStrBuilder;
    FStream: TStream;
    FBufSize,
    FByteCount,
    FPosition,
    FStackTop,
    FStackHigh: SizeInt;
    FState: Integer;
    FReadState: TReadState;
    FToken,
    FDeferToken: TTokenKind;
    FName: string;
    FValue: TJVariant;
    FReadMode,
    FCopyMode,
    FSkipBom,
    FFirstChunk: Boolean;
    function  GetIndex: SizeInt; inline;
    function  GetStructKind: TStructKind; inline;
    function  GetParentKind: TStructKind; inline;
    procedure UpdateArray; inline;
    function  NullValue: Boolean;
    function  FalseValue: Boolean;
    function  TrueValue: Boolean;
    function  NumValue: Boolean;
    procedure NameValue; inline;
    function  CommaAfterNum: Boolean;
    function  StringValue: Boolean;
    function  ArrayBegin: Boolean;
    function  ObjectBegin: Boolean;
    function  ArrayEnd: Boolean;
    function  ArrayEndAfterNum: Boolean;
    function  ObjectEnd: Boolean;
    function  ObjectEndAfterNum: Boolean;
    function  ObjectEndOb: Boolean;
    function  DeferredEnd: Boolean; inline;
    function  GetNextChunk: TReadState;
    function  GetNextToken: Boolean;
    function  GetIsNull: Boolean; inline;
    function  GetAsBoolean: Boolean; inline;
    function  GetAsNumber: Double; inline;
    function  GetAsString: string; inline;
    function  GetPath: string;
    function  GetParentName: string; inline;
    function  GetParentIndex: SizeInt; inline;
    property  ReadMode: Boolean read FReadMode;
    property  CopyMode: Boolean read FCopyMode;
    property  DeferToken: TTokenKind read FDeferToken;
  public
  const
    DEF_BUF_SIZE = 16384;
    MIN_BUF_SIZE = 1024;

    class function IsStartToken(aToken: TTokenKind): Boolean; static; inline;
    class function IsEndToken(aToken: TTokenKind): Boolean; static; inline;
    class function IsScalarToken(aToken: TTokenKind): Boolean; static; inline;
    constructor Create(aStream: TStream; aBufSize: SizeInt = DEF_BUF_SIZE;
                       aMaxDepth: SizeInt = DEF_DEPTH; aSkipBom: Boolean = False);
    destructor Destroy; override;
  { reads the next token from the stream, returns False if an error is encountered or the end
    of the stream is reached, otherwise it returns true; on error, the ReadState property
    will be set to rsError, and upon reaching the end of the stream, to rsEOF}
    function  Read: Boolean;
  { if the current token is the beginning of a structure, it skips its contents
    and stops at the closing token, otherwise it just performs one Read }
    procedure Skip;
  { iterates over all items in the current structure and calls the aFun function
    for each value item, passing Self as a parameter;
    if aFun returns False, the iteration stops immediately, otherwise it stops
    at the closing token of the current structure }
    procedure Iterate(aFun: TOnIterate);
    procedure Iterate(aFun: TNestIterate);
  { iterates over all items in the current structure and calls the aOnValue function
    for each value item or aOnStruct function for each struct item, passing Self as
    a parameter; if the called function returns False, the iteration stops immediately,
    otherwise it stops at the closing token of the current structure }
    procedure Iterate(aOnStruct, aOnValue: TOnIterate);
    procedure Iterate(aOnStruct, aOnValue: TNestIterate);
  { if the current token is the beginning of some structure(array or object),
    it copies this structure "as is" into aStruct and returns True, otherwise returns False }
    function  CopyStruct(out aStruct: string): Boolean;
  { moves to the next structure item without trying to enter nested structures;
    if the next item turns out to be a structure, it is skipped to the closing token;
    returns False if it cannot move to the next item, otherwise returns True }
    function  MoveNext: Boolean;
  { tries to find the specified key in the current structure without trying to enter
    nested structures;
    the key can be a name or a string representation of a non-negative integer;
    returns true if the key was found, otherwise returns false;
    in case of a successful search:
      if the current structure is an array and the value is a scalar,
      the search stops after reading the value with the specified index,
      otherwise the search stops at the opening token of the value;
      if the current structure is an object and the value is a scalar,
      the search stops after reading the value,
      otherwise the search stops at the opening token of the value }
    function  Find(const aKey: string): Boolean;
  { tries to find a specific place using the path specified as a JSON Pointer;
    search is possible only from the document root }
    function  FindPath(const aPtr: TJsonPtr): Boolean;
  { finds a specific place using the path specified as an array of path segments;
    search is possible only from the document root }
    function  FindPath(const aPath: TStringArray): Boolean;
  { True if current value is Null }
    property  IsNull: Boolean read GetIsNull;
  { returns the value as a Boolean, raises an exception if kind of the value <> vkBoolean }
    property  AsBoolean: Boolean read GetAsBoolean;
  { returns the value as a Double, raises an exception if kind of the value <> vkNumber }
    property  AsNumber: Double read GetAsNumber;
  { returns the value as a string, raises an exception if kind of the value <> vkString }
    property  AsString: string read GetAsString;
  { indicates the current structure index, or zero if the current structure is an object }
    property  Index: SizeInt read GetIndex;
  { indicates the current name or index if current structure is an array }
    property  Name: string read FName;
    property  Value: TJVariant read FValue;
  { returns current path as a JSON pointer (RFC 6901) }
    property  Path: string read GetPath;
    property  TokenKind: TTokenKind read FToken;
    property  StructKind: TStructKind read GetStructKind;
    property  ParentName: string read GetParentName;
    property  ParentIndex: SizeInt read GetParentIndex;
    property  ParentKind: TStructKind read GetParentKind;
  { indicates the nesting depth of the current structure, zero based }
    property  Depth: SizeInt read FStackTop;
    property  ReadState: TReadState read FReadState;
    property  SkipBom: Boolean read FSkipBom;
  end;


  function  IsExactInt(aValue: Double): Boolean; inline;
  function  IsExactInt(aValue: Double; out aIntValue: Int64): Boolean; inline;
  function  SameDouble(L, R: Double): Boolean; inline;
{ returns the shortest decimal representation of aValue formatted according
  to the following rules:
   as an integer value if aValue is an exact integer;
   in fixed point notation if -3 >= Exponent(aValue) <= 15;
   in scientific notation otherwise;
  uses Ryū Double-to-String conversion algorithm }
  procedure Double2Str(aValue: Double; out s: shortstring; aDecimalSeparator: AnsiChar = '.');
  function  Double2Str(aValue: Double; aDecimalSeparator: AnsiChar = '.'): string;
{ uses DefaultFormatSettins.DecimalSeparator as aDecimalSeparator }
  function  Double2StrDef(aValue: Double): string;
{ mostly RFC 8259 compliant: does not accept leading and trailing spaces, leading plus,
  thousand separators, leading zeros, and special values(i.e. NaN, Inf, etc) and
  expects a period as a decimal separator;
  if the result is False then aValue is undefined; uses Eisel-Lemire algorithm }
  function  TryStr2Double(const s: string; out aValue: Double): Boolean; inline;
{ returns True and the value of the number in aInt if the string s is a non-negative integer
  in decimal notation, otherwise returns False;
  leading and trailing spaces and leading zeros are not allowed }
  function  IsNonNegativeInt(const s: string; out aInt: SizeInt): Boolean;

implementation
{$B-}{$COPERATORS ON}{$POINTERMATH ON}

const
  MAX_EXACT_INT  = Double(9007199254740991); //2^53 - 1
  DBL_CMP_FACTOR = Double(1E12);
  JS_UNDEF       = 'undefined';
  JS_NULL        = 'null';
  JS_FALSE       = 'false';
  JS_TRUE        = 'true';

function IsExactInt(aValue: Double): Boolean;
begin
  Result := (Frac(aValue) = 0) and (Abs(aValue) <= MAX_EXACT_INT);
end;

function IsExactInt(aValue: Double; out aIntValue: Int64): Boolean;
begin
  if IsExactInt(aValue) then
    begin
      aIntValue := Trunc(aValue);
      exit(True);
    end;
  Result := False;
end;

function SameDouble(L, R: Double): Boolean;
begin
  Result := Abs(L - R) * DBL_CMP_FACTOR <= Min(Abs(L), Abs(R));
end;

{ TJVariant }

procedure TJVariant.DoClear;
begin
  if Kind = vkString then
    string(FValue.Ref) := ''
  else
    FValue.Int := 0;
end;

procedure TJVariant.ConvertError(const aSrc, aDst: string);
begin
  raise EInvalidCast.CreateFmt(SECantConvertFmt, [aSrc, aDst]);
end;

class operator TJVariant.Initialize(var v: TJVariant);
begin
  v.FValue.Int := 0;
  v.FKind := vkNull;
end;

class operator TJVariant.Finalize(var v: TJVariant);
begin
  v.DoClear;
end;

class operator TJVariant.Copy(constref aSrc: TJVariant; var aDst: TJVariant);
begin
  aDst.DoClear;
  if aSrc.Kind = vkString then
    string(aDst.FValue.Ref) := string(aSrc.FValue.Ref)
  else
    aDst.FValue := aSrc.FValue;
  aDst.FKind := aSrc.Kind;
end;

class operator TJVariant.AddRef(var v: TJVariant);
begin
  if v.Kind = vkString then
    UniqueString(string(v.FValue.Ref));
end;

class function TJVariant.Null: TJVariant;
begin
  Result.Clear;
end;

class operator TJVariant.:=(aValue: Double): TJVariant;
begin
  Result{%H-}.DoClear;
  Result.FValue.Num := aValue;
  Result.FKind := vkNumber;
end;

class operator TJVariant.:=(aValue: Boolean): TJVariant;
begin
  Result{%H-}.DoClear;
  Result.FValue.Bool := aValue;
  Result.FKind := vkBool;
end;

class operator TJVariant.:=(const aValue: string): TJVariant;
begin
  Result{%H-}.DoClear;
  string(Result.FValue.Ref) := aValue;
  Result.FKind := vkString;
end;

class operator TJVariant.:=(const v: TJVariant): Double;
begin
  case v.Kind of
    vkNull:   v.ConvertError('null', 'Double');
    vkBool:   v.ConvertError('Boolean', 'Double');
    vkString: v.ConvertError('string', 'Double');
  else
    exit(v.FValue.Num);
  end;
  Result := v.FValue.Num;
end;

class operator TJVariant.:=(const v: TJVariant): Int64;
begin
  if not IsExactInt(Double(v), Result) then
    v.ConvertError('Double', 'Int64');
end;

class operator TJVariant.:=(const v: TJVariant): Boolean;
begin
  case v.Kind of
    vkNull:   v.ConvertError('null', 'Boolean');
    vkNumber: v.ConvertError('Double', 'Boolean');
    vkString: v.ConvertError('string', 'Boolean');
  else
    exit(v.FValue.Bool);
  end;
  Result := v.FValue.Bool;
end;

class operator TJVariant.:=(const v: TJVariant): string;
begin
  case v.Kind of
    vkNull:   v.ConvertError('null', 'string');
    vkBool:   v.ConvertError('Boolean', 'string');
    vkNumber: v.ConvertError('Double', 'string');
  else
    exit(string(v.FValue.Ref));
  end;
  Result := string(v.FValue.Ref);
end;

class operator TJVariant.= (const L, R: TJVariant): Boolean;
begin
  case L.Kind of
    vkBool:   Result := (R.Kind = vkBool) and not(L.FValue.Bool xor R.FValue.Bool);
    vkNumber: Result := (R.Kind = vkNumber) and SameValue(L.FValue.Num, R.FValue.Num);
    vkString: Result := (R.Kind = vkString) and (string(L.FValue.Ref) = string(R.FValue.Ref));
  else
    Result := False;
  end;
end;

procedure TJVariant.Clear;
begin
  DoClear;
  FKind := vkNull;
end;

procedure TJVariant.SetNull;
begin
  Clear;
end;

function  TJVariant.IsInteger: Boolean;
begin
  if Kind <> vkNumber then
    exit(False);
  Result := IsExactInt(FValue.Num);
end;

function TJVariant.AsBoolean: Boolean;
begin
  Result := Self;
end;

function TJVariant.AsNumber: Double;
begin
  Result := Self;
end;

function TJVariant.AsInteger: Int64;
begin
  Result := Self;
end;

function TJVariant.AsString: string;
begin
  Result := Self;
end;

function TJVariant.ToString: string;
begin
  case Kind of
    vkNull:   Result := JS_NULL;
    vkBool:   Result := BoolToStr(FValue.Bool, JS_TRUE, JS_FALSE);
    vkNumber: Result := Double2StrDef(FValue.Num);
    vkString: Result := string(FValue.Ref);
  end;
end;

function JNull: TJVariant;
begin
  Result.Clear;
end;

function JPair(const aName: string; const aValue: TJVariant): TJVarPair;
begin
  Result := TJVarPair.Create(aName, aValue);
end;

const
{$PUSH}{$J-}{$WARN 2005 OFF}
  chOpenCurBr: AnsiChar  = '{';
  chClosCurBr: AnsiChar  = '}';
  chOpenSqrBr: AnsiChar  = '[';
  chClosSqrBr: AnsiChar  = ']';
  chQuote: AnsiChar      = '"';
  chColon: AnsiChar      = ':';
  chComma: AnsiChar      = ',';
  chSpace: AnsiChar      = ' ';
  chEscapeSym: AnsiChar  = '\';
  chBackSpSym: AnsiChar  = 'b';
  chTabSym: AnsiChar     = 't';
  chLineSym: AnsiChar    = 'n';
  chFormSym: AnsiChar    = 'f';
  chCarRetSym: AnsiChar  = 'r';
  chUnicodeSym: AnsiChar = 'u';
  chZero: AnsiChar       = '0';

  Space  = Integer( 0); //  space
  White  = Integer( 1); //  other whitespace
  LCurBr = Integer( 2); //  {
  RCurBr = Integer( 3); //  }
  LSqrBr = Integer( 4); //  [
  RSqrBr = Integer( 5); //  ]
  Colon  = Integer( 6); //  :
  Comma  = Integer( 7); //  ,
  Quote  = Integer( 8); //  "
  BSlash = Integer( 9); //  \
  Slash  = Integer(10); //  /
  Plus   = Integer(11); //  +
  Minus  = Integer(12); //  -
  Point  = Integer(13); //  .
  Zero   = Integer(14); //  0
  Digit  = Integer(15); //  123456789
  LowerA = Integer(16); //  a
  LowerB = Integer(17); //  b
  LowerC = Integer(18); //  c
  LowerD = Integer(19); //  d
  LowerE = Integer(20); //  e
  LowerF = Integer(21); //  f
  LowerL = Integer(22); //  l
  LowerN = Integer(23); //  n
  LowerR = Integer(24); //  r
  LowerS = Integer(25); //  s
  LowerT = Integer(26); //  t
  LowerU = Integer(27); //  u
  ABCDF  = Integer(28); //  ABCDF
  UpperE = Integer(29); //  E
  Etc    = Integer(30); //  everything else

  SymClassTable: array[0..127] of Integer = (
    -1,    -1,     -1,     -1,     -1,     -1,     -1,     -1,
    -1,    White,  White,  -1,     -1,     White,  -1,     -1,
    -1,    -1,     -1,     -1,     -1,     -1,     -1,     -1,
    -1,    -1,     -1,     -1,     -1,     -1,     -1,     -1,

    Space, Etc,    Quote,  Etc,    Etc,    Etc,    Etc,    Etc,
    Etc,   Etc,    Etc,    Plus,   Comma,  Minus,  Point,  Slash,
    Zero,  Digit,  Digit,  Digit,  Digit,  Digit,  Digit,  Digit,
    Digit, Digit,  Colon,  Etc,    Etc,    Etc,    Etc,    Etc,

    Etc,   ABCDF,  ABCDF,  ABCDF,  ABCDF,  UpperE, ABCDF,  Etc,
    Etc,   Etc,    Etc,    Etc,    Etc,    Etc,    Etc,    Etc,
    Etc,   Etc,    Etc,    Etc,    Etc,    Etc,    Etc,    Etc,
    Etc,   Etc,    Etc,    LSqrBr, BSlash, RSqrBr, Etc,    Etc,

    Etc,   LowerA, LowerB, LowerC, LowerD, LowerE, LowerF, Etc,
    Etc,   Etc,    Etc,    Etc,    LowerL, Etc,    LowerN, Etc,
    Etc,   Etc,    LowerR, LowerS, LowerT, LowerU, Etc,    Etc,
    Etc,   Etc,    Etc,    LCurBr, Etc,    RCurBr, Etc,    Etc
  );

  __ = Integer(-1);// error
  GO = Integer( 0);// start
  OK = Integer( 1);// ok
  OB = Integer( 2);// object
  KE = Integer( 3);// key
  CO = Integer( 4);// colon
  VA = Integer( 5);// value
  AR = Integer( 6);// array
  ST = Integer( 7);// string
  ES = Integer( 8);// escape
  U1 = Integer( 9);// u1
  U2 = Integer(10);// u2
  U3 = Integer(11);// u3
  U4 = Integer(12);// u4
  MI = Integer(13);// minus
  ZE = Integer(14);// zero
  IR = Integer(15);// integer
  FR = Integer(16);// fraction
  FS = Integer(17);// fraction
  E1 = Integer(18);// e
  E2 = Integer(19);// ex
  E3 = Integer(20);// exp
  T1 = Integer(21);// tr
  T2 = Integer(22);// tru
  T3 = Integer(23);// true
  F1 = Integer(24);// fa
  F2 = Integer(25);// fal
  F3 = Integer(26);// fals
  F4 = Integer(27);// false
  N1 = Integer(28);// nu
  N2 = Integer(29);// nul
  N3 = Integer(30);// null

  VldStateTransitions: array[GO..N3, Space..Etc] of Integer = (
{
  The state transition table takes the current state and the current symbol,
  and returns either a new state or an action. An action is represented as a
  negative number. A JSON text is accepted if at the end of the text the
  state is OK and if the mode is MODE_DONE.

             white                                      1-9                                   ABCDF  etc
         space |  {  }  [  ]  :  ,  "  \  /  +  -  .  0  |  a  b  c  d  e  f  l  n  r  s  t  u  |  E  | }
{start  GO}(GO,GO,-6,__,-5,__,__,__,ST,__,__,__,MI,__,ZE,IR,__,__,__,__,__,F1,__,N1,__,__,T1,__,__,__,__),
{ok     OK}(OK,OK,__,-8,__,-7,__,-3,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{object OB}(OB,OB,__,-9,__,__,__,__,ST,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{key    KE}(KE,KE,__,__,__,__,__,__,ST,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{colon  CO}(CO,CO,__,__,__,__,-2,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{value  VA}(VA,VA,-6,__,-5,__,__,__,ST,__,__,__,MI,__,ZE,IR,__,__,__,__,__,F1,__,N1,__,__,T1,__,__,__,__),
{array  AR}(AR,AR,-6,__,-5,-7,__,__,ST,__,__,__,MI,__,ZE,IR,__,__,__,__,__,F1,__,N1,__,__,T1,__,__,__,__),
{string ST}(ST,__,ST,ST,ST,ST,ST,ST,-4,ES,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST),
{escape ES}(__,__,__,__,__,__,__,__,ST,ST,ST,__,__,__,__,__,__,ST,__,__,__,ST,__,ST,ST,__,ST,U1,__,__,__),
{u1     U1}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,U2,U2,U2,U2,U2,U2,U2,U2,__,__,__,__,__,__,U2,U2,__),
{u2     U2}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,U3,U3,U3,U3,U3,U3,U3,U3,__,__,__,__,__,__,U3,U3,__),
{u3     U3}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,U4,U4,U4,U4,U4,U4,U4,U4,__,__,__,__,__,__,U4,U4,__),
{u4     U4}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,ST,ST,ST,ST,ST,ST,ST,ST,__,__,__,__,__,__,ST,ST,__),
{minus  MI}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,ZE,IR,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{zero   ZE}(OK,OK,__,-8,__,-7,__,-3,__,__,__,__,__,FR,__,__,__,__,__,__,E1,__,__,__,__,__,__,__,__,E1,__),
{int    IR}(OK,OK,__,-8,__,-7,__,-3,__,__,__,__,__,FR,IR,IR,__,__,__,__,E1,__,__,__,__,__,__,__,__,E1,__),
{frac   FR}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,FS,FS,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{fracs  FS}(OK,OK,__,-8,__,-7,__,-3,__,__,__,__,__,__,FS,FS,__,__,__,__,E1,__,__,__,__,__,__,__,__,E1,__),
{e      E1}(__,__,__,__,__,__,__,__,__,__,__,E2,E2,__,E3,E3,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{ex     E2}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,E3,E3,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{exp    E3}(OK,OK,__,-8,__,-7,__,-3,__,__,__,__,__,__,E3,E3,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{tr     T1}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,T2,__,__,__,__,__,__),
{tru    T2}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,T3,__,__,__),
{true   T3}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,OK,__,__,__,__,__,__,__,__,__,__),
{fa     F1}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,F2,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{fal    F2}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,F3,__,__,__,__,__,__,__,__),
{fals   F3}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,F4,__,__,__,__,__),
{false  F4}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,OK,__,__,__,__,__,__,__,__,__,__),
{nu     N1}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,N2,__,__,__),
{nul    N2}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,N3,__,__,__,__,__,__,__,__),
{null   N3}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,OK,__,__,__,__,__,__,__,__)
  );
{$POP}

type
  TBomKind = (bkNone, bkUtf8, bkUtf16, bkUtf32);

const
  UTF8_BOM_LEN = 3;
  INF_EXP      = QWord($7ff0000000000000);
  NUM_STATES   = Integer(1 shl ZE or 1 shl IR or 1 shl FS or 1 shl E3);

function DetectBom(aBuf: PByte; aBufSize: SizeInt): TBomKind;
{$PUSH}{$J-}
const
  U16LE: array[0..1] of Byte = ($FF, $FE);
  U16BE: array[0..1] of Byte = ($FE, $FF);
  UTF8:  array[0..2] of Byte  =($EF, $BB, $BF);
  U32LE: array[0..3] of Byte = ($FF, $FE, $00, $00);
  U32BE: array[0..3] of Byte = ($00, $00, $FE, $FF);
{$POP}
  function IsUtf16(p: PByte): Boolean;
  begin
    Result := ((p[0] xor U16LE[0]) or (p[1] xor U16LE[1]) = 0) or
              ((p[0] xor U16BE[0]) or (p[1] xor U16BE[1]) = 0);
  end;
  function IsUtf8(p: PByte): Boolean;
  begin
    Result := (p[0] xor UTF8[0]) or (p[1] xor UTF8[1]) or (p[2] xor UTF8[2]) = 0;
  end;
  function IsUtf32(p: PByte): Boolean;
  begin
    Result := ((p[0] xor U32LE[0]) or (p[1] xor U32LE[1]) or
               (p[2] xor U32LE[2]) or (p[3] xor U32LE[3]) = 0) or
              ((p[0] xor U32BE[0]) or (p[1] xor U32BE[1]) or
               (p[2] xor U32BE[2]) or (p[3] xor U32BE[3]) = 0);
  end;
begin
  if (aBufSize >= 2) and IsUtf16(aBuf) then exit(bkUtf16);
  if (aBufSize >= 3) and IsUtf8(aBuf) then exit(bkUtf8);
  if (aBufSize >= 4) and IsUtf32(aBuf) then exit(bkUtf32);
  Result := bkNone;
end;

{$PUSH}{$MACRO ON}
{$DEFINE ValidateBufMacro :=
for I := 0 to Pred(Size) do
  begin
    if Buf[I] < 128 then begin
      NextClass := SymClassTable[Buf[I]];
      if NextClass = __ then exit(False);
    end else
      NextClass := Etc;
    NextState := VldStateTransitions[State, NextClass];
    if NextState >= 0 then
      State := NextState
    else
      case NextState of
        -9:
          begin
            if Stack[sTop] <> pmKey then exit(False);
            Dec(sTop);
            State := OK;
          end;
        -8:
          begin
            if Stack[sTop] <> pmObject then exit(False);
            Dec(sTop);
            State := OK;
          end;
        -7:
          begin
            if Stack[sTop] <> pmArray then exit(False);
            Dec(sTop);
            State := OK;
          end;
        -6:
          begin
            if sTop >= StackHigh then exit(False);
            Inc(sTop);
            Stack[sTop] := pmKey;
            State := OB;
          end;
        -5:
          begin
            if sTop >= StackHigh then exit(False);
            Inc(sTop);
            Stack[sTop] := pmArray;
            State := AR;
          end;
        -4:
          case Stack[sTop] of
            pmKey:                     State := CO;
            pmNone, pmArray, pmObject: State := OK;
          end;
        -3:
          case Stack[sTop] of
            pmObject:
              begin
                Stack[sTop] := pmKey;
                State := KE;
              end;
            pmArray: State := VA;
          else
            exit(False);
          end;
        -2:
          begin
            if Stack[sTop] <> pmKey then exit(False);
            Stack[sTop] := pmObject;
            State := VA;
          end;
      else
        exit(False);
      end;
  end
}

type
  TOpenArray = record
    Data: Pointer;
    Size: Integer;
    constructor Create(aData: Pointer; aSize: Integer);
  end;

constructor TOpenArray.Create(aData: Pointer; aSize: Integer);
begin
  Data := aData;
  Size := aSize;
end;

function ValidateBuf(Buf: PByte; Size: SizeInt; const aStack: TOpenArray): Boolean;
var
  Stack: PParseMode;
  I: SizeInt;
  NextState, NextClass, StackHigh: Integer;
  State: Integer = GO;
  sTop: Integer = 0;
begin
  Stack := aStack.Data;
  StackHigh := Pred(aStack.Size);
  Stack[0] := pmNone;
  ValidateBufMacro;
  Result := ((State = OK) or (State in [ZE, IR, FS, E3])) and (sTop = 0) and (Stack[0] = pmNone);
end;

function ValidateStrBuf(Buf: PByte; Size: SizeInt; const aStack: TOpenArray): Boolean;
var
  Stack: PParseMode;
  I: SizeInt;
  NextState, NextClass, StackHigh: Integer;
  State: Integer = GO;
  sTop: Integer = 0;
begin
  Stack := aStack.Data;
  StackHigh := Pred(aStack.Size);
  Stack[0] := pmNone;
  ValidateBufMacro;
  Result := (State = OK) and (sTop = 0) and (Stack[0] = pmNone);
end;

function ValidateNumBuf(Buf: PByte; Size: SizeInt; const aStack: TOpenArray): Boolean;
var
  Stack: PParseMode;
  I: SizeInt;
  NextState, NextClass, StackHigh: Integer;
  State: Integer = GO;
  sTop: Integer = 0;
begin
  Stack := aStack.Data;
  StackHigh := Pred(aStack.Size);
  Stack[0] := pmNone;
  ValidateBufMacro;
  Result := (State in [Ze, IR, FS, E3]) and (sTop = 0) and (Stack[0] = pmNone);
end;

function ValidateStream(s: TStream; aSkipBom: Boolean; const aStack: TOpenArray): Boolean;
var
  Stack: PParseMode;
  Buffer: TJsonNode.TRwBuffer;
  I, Size: SizeInt;
  NextState, NextClass, StackHigh: Integer;
  State: Integer = GO;
  sTop: Integer = 0;
  Buf: PByte;
begin
  Stack := aStack.Data;
  StackHigh := Pred(aStack.Size);
  Stack[0] := pmNone;
  Buf := @Buffer[0];
  Size := s.Read(Buffer, SizeOf(Buffer));
  if Size < 1 then exit(False);
  if aSkipBom then
    case DetectBom(Buf, Size) of
      bkNone: ;
      bkUtf8:
        begin
          Buf += UTF8_BOM_LEN;
          Size -= UTF8_BOM_LEN;
        end;
    else
      exit(False);
    end;
  ValidateBufMacro;
  Buf := @Buffer[0];
  repeat
    Size := s.Read(Buffer, SizeOf(Buffer));
    ValidateBufMacro;
  until Size < SizeOf(Buffer);
  Result := ((State = OK) or (State in [ZE, IR, FS, E3])) and (sTop = 0) and (Stack[0] = pmNone);
end;
{$POP}

{ TJsonNode.TIterContext }

constructor TJsonNode.TIterContext.Init(aLevel, aIndex: SizeInt; aParent: TJsonNode);
begin
  Level := aLevel;
  Index := aIndex;
  Name := '';
  Parent := aParent;
end;

constructor TJsonNode.TIterContext.Init(aLevel: SizeInt; const aName: string; aParent: TJsonNode);
begin
  Level := aLevel;
  Index := NULL_INDEX;
  Name := aName;
  Parent := aParent;
end;

constructor TJsonNode.TIterContext.Init(aParent: TJsonNode);
begin
  Level := 0;
  Index := NULL_INDEX;
  Name := '';
  Parent := aParent;
end;

{ TJsonNode.TVisitNode }

constructor TJsonNode.TVisitNode.Init(aLevel, aIndex: SizeInt; aParent, aNode: TJsonNode);
begin
  Level := aLevel;
  Index := aIndex;
  Name := '';
  Parent := aParent;
  Node := aNode;
end;

constructor TJsonNode.TVisitNode.Init(aLevel: SizeInt; const aName: string; aParent, aNode: TJsonNode);
begin
  Level := aLevel;
  Index := NULL_INDEX;
  Name := aName;
  Parent := aParent;
  Node := aNode;
end;

constructor TJsonNode.TVisitNode.Init(aNode: TJsonNode);
begin
  Level := 0;
  Index := NULL_INDEX;
  Name := '';
  Parent := nil;
  Node := aNode;
end;

{ TJsonNode.TStrBuilder }

constructor TJsonNode.TStrBuilder.Create(aCapacity: SizeInt);
begin
  if aCapacity > 0 then
    System.SetLength(FBuffer, lgUtils.RoundUpTwoPower(aCapacity))
  else
    System.SetLength(FBuffer, DEFAULT_CONTAINER_CAPACITY);
  FCount := 0;
end;

constructor TJsonNode.TStrBuilder.Create(const s: string);
begin
  System.SetLength(FBuffer, System.Length(s));
  System.Move(Pointer(s)^, Pointer(FBuffer)^, System.Length(s));
end;

function TJsonNode.TStrBuilder.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TJsonNode.TStrBuilder.NonEmpty: Boolean;
begin
  Result := Count <> 0;
end;

procedure TJsonNode.TStrBuilder.MakeEmpty;
begin
  FCount := 0;
end;

procedure TJsonNode.TStrBuilder.EnsureCapacity(aCapacity: SizeInt);
begin
  if aCapacity > System.Length(FBuffer) then
    System.SetLength(FBuffer, lgUtils.RoundUpTwoPower(aCapacity));
end;

procedure TJsonNode.TStrBuilder.Append(c: AnsiChar);
begin
  EnsureCapacity(Count + 1);
  FBuffer[Count] := c;
  Inc(FCount);
end;

procedure TJsonNode.TStrBuilder.Append(c: AnsiChar; aCount: SizeInt);
begin
  EnsureCapacity(Count + aCount);
  FillChar(FBuffer[Count], aCount, c);
  FCount += aCount;
end;

procedure TJsonNode.TStrBuilder.Append(const s: string);
begin
  EnsureCapacity(Count + System.Length(s));
  System.Move(Pointer(s)^, FBuffer[Count], System.Length(s));
  FCount += System.Length(s);
end;

procedure TJsonNode.TStrBuilder.AppendEncode(const s: string);
var
  I: SizeInt;
const
  HexChars: PChar = '0123456789ABCDEF';
begin
  Append('"');
  for I := 1 to System.Length(s) do
    case s[I] of
      #0..#7, #11, #14..#31:
        begin
           Append(chEscapeSym);
           Append(chUnicodeSym);
           Append(chZero);
           Append(chZero);
           Append(HexChars[Ord(s[I]) shr  4]);
           Append(HexChars[Ord(s[I]) and 15]);
        end;
      #8 : begin Append(chEscapeSym); Append(chBackSpSym) end; //backspace
      #9 : begin Append(chEscapeSym); Append(chTabSym) end;    //tab
      #10: begin Append(chEscapeSym); Append(chLineSym) end;   //line feed
      #12: begin Append(chEscapeSym); Append(chFormSym) end;   //form feed
      #13: begin Append(chEscapeSym); Append(chCarRetSym) end; //carriage return
      '"': begin Append(chEscapeSym); Append('"') end;         //quote
      '\': begin Append(chEscapeSym); Append('\') end;         //backslash
    else
      Append(s[I]);
    end;
  Append('"');
end;

procedure TJsonNode.TStrBuilder.Append(const s: shortstring);
begin
  EnsureCapacity(Count + System.Length(s));
  System.Move(s[1], FBuffer[Count], System.Length(s));
  FCount += System.Length(s);
end;

function TJsonNode.TStrBuilder.SaveToStream(aStream: TStream): SizeInt;
begin
  aStream.WriteBuffer(Pointer(FBuffer)^, Count);
  Result := Count;
  FCount := 0;
end;

function TJsonNode.TStrBuilder.ToString: string;
begin
  System.SetLength(Result, Count);
  System.Move(Pointer(FBuffer)^, Pointer(Result)^, Count);
  FCount := 0;
end;

type
  TChar2 = array[0..1] of AnsiChar;
  TChar3 = array[0..2] of AnsiChar;
  TChar4 = array[0..3] of AnsiChar;
  PChar2 = ^TChar2;
  PChar3 = ^TChar3;
  PChar4 = ^TChar4;

function UxSeqToUtf8(const uSeq: TChar4): TChar4; inline;
const
  xV: array['0'..'f'] of DWord = (
   0, 1, 2, 3, 4, 5, 6, 7, 8, 9,15,15,15,15,15,15,
  15,10,11,12,13,14,15,15,15,15,15,15,15,15,15,15,
  15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
  15,10,11,12,13,14,15);
var
  cPt: DWord;
begin
  cPt := xV[uSeq[0]] shl 12 or xV[uSeq[1]] shl 8 or xV[uSeq[2]] shl 4 or xV[uSeq[3]];
  case cPt of
    0..$7f:
      begin
        Result[0] := AnsiChar(cPt);
        Result[3] := #1;
      end;
    $80..$7ff:
      begin
        Result[0] := AnsiChar((cPt shr  6) + $c0);
        Result[1] := AnsiChar((cPt and $3f) + $80);
        Result[3] := #2;
      end;
    $800..$ffff:
      begin
        Result[0] := AnsiChar((cPt shr 12) + $e0);
        Result[1] := AnsiChar(((cPt shr 6) and $3f) + $80);
        Result[2] := AnsiChar((cPt and $3f) + $80);
        Result[3] := #3;
      end;
  else
    Result[3] := #0;
  end;
end;

function TJsonNode.TStrBuilder.ToDecodeString: string;
var
  r: string;
  I, J, Last: SizeInt;
  pR: PAnsiChar;
  c4: TChar4;
begin
  System.SetLength(r, Count);
  Last := Pred(Count);
  I := 1;
  J := 0;
  pR := PAnsiChar(r);
  while I < Last do
    if FBuffer[I] <> '\' then
      begin
        pR[J] := FBuffer[I];
        Inc(I);
        Inc(J);
      end
    else
      case FBuffer[Succ(I)] of
        'b':
          begin
            pR[J] := #8;
            I += 2;
            Inc(J);
          end;
        'f':
          begin
            pR[J] := #12;
            I += 2;
            Inc(J);
          end;
        'n':
          begin
            pR[J] := #10;
            I += 2;
            Inc(J);
          end;
        'r':
          begin
            pR[J] := #13;
            I += 2;
            Inc(J);
          end;
        't':
          begin
            pR[J] := #9;
            I += 2;
            Inc(J);
          end;
        'u':
          begin
            c4 := UxSeqToUtf8(PChar4(@FBuffer[I+2])^);
            case c4[3] of
              #1:
                begin
                  pR[J] := c4[0];
                  Inc(J);
                end;
              #2:
                begin
                  PChar2(@pR[J])^ := PChar2(@c4[0])^;
                  J += 2;
                end;
              #3:
                begin
                  PChar3(@pR[J])^ := PChar3(@c4[0])^;
                  J += 3;
                end;
            else
            end;
            I += 6;
          end;
      else
        pR[J] := FBuffer[Succ(I)];
        I += 2;
        Inc(J)
      end;
  System.SetLength(r, J);
  Result := r;
  FCount := 0;
end;

function TJsonNode.TStrBuilder.ToPChar: PAnsiChar;
begin
  EnsureCapacity(Succ(Count));
  FBuffer[Count] := #0;
  FCount := 0;
  Result := Pointer(FBuffer);
end;

{ TJsonPtr.TEnumerator }

function TJsonPtr.TEnumerator.GetCurrent: string;
begin
  Result := FList[FIndex];
end;

function TJsonPtr.TEnumerator.MoveNext: Boolean;
begin
  if FIndex < System.High(FList) then
    begin
      Inc(FIndex);
      exit(True);
    end;
  Result := False;
end;

{ TJsonPtr }

function TJsonPtr.GetCount: SizeInt;
begin
  Result := System.Length(FSegments);
end;

function TJsonPtr.GetSegment(aIndex: SizeInt): string;
begin
  if SizeUInt(aIndex) >= SizeUInt(System.Length(FSegments)) then
    raise EJsException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
  Result := FSegments[aIndex];
end;

class function TJsonPtr.Encode(const aSegs: array of string): string;
var
  sb: TJsonNode.TStrBuilder;
  I, J: SizeInt;
begin
  Result := '';
  sb := TJsonNode.TStrBuilder.Create(TJsonNode.S_BUILD_INIT_SIZE);
  for I := 0 to System.High(aSegs) do
    begin
      sb.Append('/');
      for J := 1 to System.Length(aSegs[I]) do
        case aSegs[I][J] of
          '/':
            begin
              sb.Append('~');
              sb.Append('1');
            end;
          '~':
            begin
              sb.Append('~');
              sb.Append('0');
            end;
        else
          sb.Append(aSegs[I][J]);
        end;
    end;
  Result := sb.ToString;
end;

{$PUSH}{$WARN 5089 OFF}{$WARN 5036 OFF}
class function TJsonPtr.Decode(const s: string): TStringArray;
var
  pSeg: PAnsiChar;
  SegIdx: Integer;
  procedure AppendChar(c: AnsiChar); inline;
  begin
    pSeg[SegIdx] := c;
    Inc(SegIdx);
  end;
var
  CurrSeg: string;
  Segs: TStringArray;
  J: SizeInt;
  procedure AddSegment; inline;
  begin
    System.SetLength(CurrSeg, SegIdx);
    SegIdx := 0;
    if System.Length(Segs) = J then
      System.SetLength(Segs, J * 2);
    Segs[J] := CurrSeg;
    Inc(J);
  end;
var
  I, Len: SizeInt;
  c: AnsiChar;
begin
  Result := nil;
  if (s = '') then
    exit;
  if s[1] <> '/' then
    raise EJsException.Create(SEInvalidJsPtr);
  if s = '/' then
    exit(['']);
  Len := System.Length(s);
  if s[Len] = '~' then
    raise EJsException.Create(SEInvalidJsPtr);

  System.SetLength(Segs, ARRAY_INITIAL_SIZE);
  System.SetLength(CurrSeg, Len - 1);
  pSeg := Pointer(CurrSeg);
  J := 0;
  SegIdx := 0;
  I := 2;
  while I <= Len do
    begin
      c := s[I];
      case c of
        '/':
          begin
            AddSegment;
            System.SetLength(CurrSeg, Len - I);
            pSeg := Pointer(CurrSeg);
          end;
        '~':
          begin
            case s[I+1] of
              '0': AppendChar('~');
              '1': AppendChar('/');
            else
              raise EJsException.Create(SEInvalidJsPtr);
            end;
            Inc(I);
          end
      else
        AppendChar(c);
      end;
      Inc(I);
    end;
  AddSegment;
  System.SetLength(Segs, J);
  Result := Segs;
end;
{$POP}

class function TJsonPtr.ValidPtr(const s: string): Boolean;
var
  I: SizeInt;
begin
  if s = '' then
    exit(True);
  if s[1] <> '/' then
    exit(False);
  for I := 2 to Pred(System.Length(s)) do
    if (s[I] = '~') and not (s[Succ(I)] in ['0'..'1']) then
      exit(False);
  if s[System.Length(s)] = '~' then
    exit(False);
  Result := True;
end;

class function TJsonPtr.ValidAlien(const s: string): Boolean;
var
  sb: TJsonNode.TStrBuilder;
begin
  if not TJsonNode.JsonStringValid(s) then
    exit(False);
  sb := TJsonNode.TStrBuilder.Create(s);
  Result := ValidPtr(sb.ToDecodeString);
end;

class function TJsonPtr.ToSegments(const aPtr: string): TStringArray;
begin
  Result := Decode(aPtr);
end;

class function TJsonPtr.TryGetSegments(const aPtr: string; out aSegs: TStringArray): Boolean;
begin
  try
    aSegs := Decode(aPtr);
    Result := True;
  except
    Result := False;
  end;
end;

class function TJsonPtr.ToPointer(const aSegments: array of string): string;
begin
  Result := Encode(aSegments);
end;

class operator TJsonPtr.=(const L, R: TJsonPtr): Boolean;
var
  I: SizeInt;
begin
  if System.Length(L.FSegments) <> System.Length(R.FSegments) then
    exit(False);
  for I := 0 to System.High(L.FSegments) do
    if L.FSegments[I] <> R.FSegments[I] then
      exit(False);
  Result := True;
end;

constructor TJsonPtr.From(const s: string);
begin
  FSegments := Decode(s);
end;

constructor TJsonPtr.From(const aPath: array of string);
begin
  FSegments := specialize TGArrayHelpUtil<string>.CreateCopy(aPath);
end;

constructor TJsonPtr.FromAlien(const s: string);
var
  sb: TJsonNode.TStrBuilder;
begin
  sb := TJsonNode.TStrBuilder.Create(s);
  FSegments := Decode(sb.ToDecodeString);
end;

function TJsonPtr.GetEnumerator: TEnumerator;
begin
  Result.FList := FSegments;
  Result.FIndex := NULL_INDEX;
end;

function TJsonPtr.IsEmpty: Boolean;
begin
  Result := System.Length(FSegments) = 0;
end;

function TJsonPtr.NonEmpty: Boolean;
begin
  Result := System.Length(FSegments) <> 0;
end;

procedure TJsonPtr.Clear;
begin
  FSegments := nil;
end;

procedure TJsonPtr.Append(const aSegment: string);
begin
  System.Insert(aSegment, FSegments, Count);
end;

function TJsonPtr.ToString: string;
begin
  Result := Encode(FSegments);
end;

function TJsonPtr.ToAlien: string;
var
  sb: TJsonNode.TStrBuilder;
begin
  sb := TJsonNode.TStrBuilder.Create(TJsonNode.S_BUILD_INIT_SIZE);
  sb.AppendEncode(Encode(FSegments));
  Result := sb.ToString;
end;

function TJsonPtr.ToSegments: TStringArray;
begin
  Result := System.Copy(FSegments);
end;

{ TJsonNode.TEmptyPairEnumerator }

function TJsonNode.TEmptyPairEnumerator.GetCurrent: TPair;
begin
  Result := Default(TPair);
end;

function TJsonNode.TEmptyPairEnumerator.MoveNext: Boolean;
begin
  Result := False;
end;

procedure TJsonNode.TEmptyPairEnumerator.Reset;
begin
end;

{ TJsonNode.TEqualEnumerator }

function TJsonNode.TEqualEnumerator.GetCurrent: TPair;
begin
  Result := FEnum.Current;
end;

constructor TJsonNode.TEqualEnumerator.Create(const aEnum: TJsObject.TEqualEnumerator);
begin
  FEnum := aEnum;
end;

function TJsonNode.TEqualEnumerator.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TJsonNode.TEqualEnumerator.Reset;
begin
  FEnum.Reset;
end;

procedure TJsonNode.TNodeEnumerator.Reset;
begin
  FQueue.Clear;
  FQueue.Enqueue(FStart);
end;

{ TJsonNode }

class function TJsonNode.CreateJsArray: PJsArray;
begin
  Result := System.GetMem(SizeOf(TJsArray));
  FillChar(Result^, SizeOf(TJsArray), 0);
end;

class procedure TJsonNode.FreeJsArray(a: PJsArray);
var
  I: SizeInt;
begin
  if a <> nil then
    begin
      for I := 0 to Pred(a^.Count) do
        a^.UncMutable[I]^.Free;
      System.Finalize(a^);
      FreeMem(a);
    end;
end;

class function TJsonNode.CreateJsObject: PJsObject;
begin
  Result := GetMem(SizeOf(TJsObject));
  FillChar(Result^, SizeOf(TJsObject), 0);
end;

class procedure TJsonNode.FreeJsObject(o: PJsObject);
var
  I: SizeInt;
begin
  if o <> nil then
    begin
      for I := 0 to Pred(o^.Count) do
        o^.Mutable[I]^.Value.Free;
      System.Finalize(o^);
      FreeMem(o);
    end;
end;

function TJsonNode.GetFString: string;
begin
  Result := string(FValue.Ref);
end;

function TJsonNode.GetFArray: PJsArray;
begin
  Result := FValue.Ref;
end;

function TJsonNode.GetFObject: PJsObject;
begin
  Result := FValue.Ref;
end;

procedure TJsonNode.SetFString(const aValue: string);
begin
  string(FValue.Ref) := aValue;
end;

procedure TJsonNode.SetFArray(aValue: PJsArray);
begin
  FValue.Ref := aValue;
end;

procedure TJsonNode.SetFObject(aValue: PJsObject);
begin
  FValue.Ref := aValue;
end;

procedure TJsonNode.DoClear;
begin
  case FKind of
    jvkNumber: FValue.Int := 0;
    jvkString: FString := '';
    jvkArray:
      begin
        FreeJsArray(FValue.Ref);
        FValue.Ref := nil;
      end;
    jvkObject:
      begin
        FreeJsObject(FValue.Ref);
        FValue.Ref := nil;
      end;
  else
  end;
end;

function TJsonNode.GetAsArray: TJsonNode;
begin
  if Kind <> jvkArray then
    begin
      DoClear;
      FKind := jvkArray;
    end;
  Result := Self;
end;

function TJsonNode.GetAsObject: TJsonNode;
begin
  if Kind <> jvkObject then
    begin
      DoClear;
      FKind := jvkObject;
    end;
  Result := Self;
end;

function TJsonNode.GetAsNull: TJsonNode;
begin
  if Kind <> jvkNull then
    begin
      DoClear;
      FKind := jvkNull;
    end;
  Result := Self;
end;

function TJsonNode.GetAsBoolean: Boolean;
begin
  if Kind = jvkTrue then
    exit(True);
  if Kind <> jvkFalse then
    begin
      DoClear;
      FKind := jvkFalse;
    end;
  Result := False;
end;

procedure TJsonNode.SetAsBoolean(aValue: Boolean);
begin
  if aValue then
    if Kind <> jvkTrue then
      begin
        DoClear;
        FKind := jvkTrue;
      end else
  else
    if Kind <> jvkFalse then
      begin
        DoClear;
        FKind := jvkFalse;
      end;
end;

function TJsonNode.GetAsNumber: Double;
begin
  if Kind <> jvkNumber then
    begin
      DoClear;
      FKind := jvkNumber;
    end;
  Result := FValue.Num;
end;

procedure TJsonNode.SetAsNumber(aValue: Double);
begin
  if Kind <> jvkNumber then
    begin
      DoClear;
      FKind := jvkNumber;
    end;
  FValue.Num := aValue;
end;

function TJsonNode.GetAsString: string;
begin
  if Kind <> jvkString then
    begin
      DoClear;
      FKind := jvkString;
    end;
  Result := FString;
end;

procedure TJsonNode.SetAsString(const aValue: string);
begin
  if Kind <> jvkString then
    begin
      DoClear;
      FKind := jvkString;
    end;
  FString := aValue;
end;

type
  TOWord = record
    Lo, Hi: QWord;
  end;

{$PUSH}{$Q-}{$R-}{$J-}{$WARN 5036 OFF}{$WARN 4081 OFF}
procedure UMul64Full({$IFDEF CPUX86}constref{$ELSE}const{$ENDIF}x, y: QWord; out aProd: TOWord);
{$IF DEFINED(CPUX64)}{$ASMMODE INTEL} assembler; nostackframe;
asm
{$IFDEF MSWINDOWS}
  mov rax, rcx
  mul rdx
{$ELSE MSWINDOWS}
  mov rax, rdi
  mov r8,  rdx
  mul rsi
{$ENDIF MSWINDOWS}
  mov qword ptr[r8  ], rax
  mov qword ptr[r8+8], rdx
end;
{$ELSEIF DEFINED(CPUAARCH64)} assembler; nostackframe;
asm
  mul   x3, x0, x1
  umulh x4, x0, x1
  stp   x3, x4, [x2]
end;
{$ELSEIF DEFINED(CPUX86)}{$ASMMODE INTEL} assembler; nostackframe;
asm
  sub   esp, 16
  mov   [esp  ], esi
  mov   [esp+4], edi
  mov   [esp+8], ebx
//////////////////////////////////
  mov   esi, eax                  // esi <- @x
  mov   edi, edx                  // edi <- @y
//////////////////////////////////// mul x by Lo(y)
  mov   eax, [eax]
  mul   dword ptr[edi]
  mov   [ecx], eax
  mov   [ecx+4], edx

  mov   eax, [esi+4]
  mul   dword ptr[edi]
  add   [ecx+4], eax
  adc   edx, 0
  mov   [ecx+8], edx
/////////////////////////////////  mul x by Hi(y)
  mov   eax, [esi]
  mul   dword ptr[edi+4]
  mov   ebx, edx
  add   [ecx+4], eax
  adc   ebx, 0

  mov   eax, [esi+4]
  mul   dword ptr[edi+4]
  add   eax, ebx
  adc   edx, 0
  add   [ecx+8], eax
  adc   edx, 0
  mov   [ecx+12], edx
//////////////////////////////////
  mov  esi, [esp  ]
  mov  edi, [esp+4]
  mov  ebx, [esp+8]
  add  esp, 16
end;
{$ELSE}
var
  p00, p01, mid: QWord;
begin
  p00 := QWord(DWord(x)) * DWord(y);
  p01 := DWord(x) * (y shr 32);
  mid := (x shr 32) * DWord(y) + p00 shr 32 + DWord(p01);
  aProd.Lo := mid shl 32 or DWord(p00);
  aProd.Hi := (x shr 32) * (y shr 32) + mid shr 32 + p01 shr 32;
end;
{$ENDIF}

{ for internal use only }
function RShift128(const aLo, aHi: QWord; aShift: Integer): QWord; inline;
begin
  Result := aLo shr aShift or aHi shl (64 - aShift);
end;

{ for internal use only }
function MulShift64(const aM: QWord; aMul: PQWord; aJ: Integer): QWord; inline;
type
  TQWord2 = array[0..1] of QWord;
  PQWord2 = ^TQWord2;
var
  o: TOWord;
  Lo: QWord;
begin
  UMul64Full(aM, PQWord2(aMul)^[0], o);
  Lo := o.Hi;
  UMul64Full(aM, PQWord2(aMul)^[1], o);
  Lo += o.Lo;
  Result := RShift128(Lo, o.Hi + QWord(Lo < o.Lo), aJ - 64);
end;

{ for internal use only }
function MulShiftAll64(const aM: QWord; aMul: PQWord; aJ: Integer; out aVP, aVM: QWord; aMMShift: DWord): QWord; inline;
begin
  aVP := MulShift64(aM * 4 + 2, aMul, aJ);
  aVM := MulShift64(Pred(aM * 4) - aMMShift, aMul, aJ);
  Result := MulShift64(aM * 4, aMul, aJ);
end;

{ for internal use only }
function Pow5Factor(aValue: QWord): DWord; inline;
const
  Inv5  = QWord(14757395258967641293);
  nDiv5 = QWord(3689348814741910323);
begin
  Result := 0;
  repeat
    aValue := aValue * Inv5;
    if aValue > nDiv5 then break;
    Inc(Result);
  until False;
end;

{ for internal use only }
function MultipleOfPowerOf5(const aValue: QWord; aP: DWord): Boolean; inline;
begin
  Result := Pow5Factor(aValue) >= aP;
end;

{ for internal use only }
function MultipleOfPowerOf2(const aValue: QWord; aP: DWord): Boolean; inline;
begin
  Result := aValue and Pred(QWord(1) shl aP) = 0;
end;

{ for internal use only }
function Log10Pow2(e: Integer): Integer; inline;
begin
  Result := (DWord(e) * QWord(169464822037455)) shr 49;
end;

{ for internal use only }
function Log10Pow5(e: Integer): Integer; inline;
begin
  Result := (DWord(e) * QWord(196742565691928)) shr 48;
end;

{ for internal use only }
function Pow5Bits(e: Integer): Integer; inline;
begin
  Result := Succ(Integer((QWord(e) * QWord(163391164108059)) shr 46));
end;

{ for internal use only }
function Log2Pow5(e: Integer): Integer; inline;
begin
 Result := (DWord(e) * DWord(1217359)) shr 19;
end;

{ for internal use only }
function GetDecimalLen(const aValue: QWord): Integer; inline;
begin
  case aValue of
    0..9: Result := 1;
    10..99: Result := 2;
    100..999: Result := 3;
    1000..9999: Result := 4;
    10000..99999: Result := 5;
    100000..999999: Result := 6;
    1000000..9999999: Result := 7;
    10000000..99999999: Result := 8;
    100000000..999999999: Result := 9;
    1000000000..9999999999: Result := 10;
    10000000000..99999999999: Result := 11;
    100000000000..999999999999: Result := 12;
    1000000000000..9999999999999: Result := 13;
    10000000000000..99999999999999: Result := 14;
    100000000000000..999999999999999: Result := 15;
    1000000000000000..9999999999999999: Result := 16;
    10000000000000000..99999999999999999: Result := 17;
    100000000000000000..999999999999999999: Result := 18;
    1000000000000000000..9999999999999999999: Result := 19;
  else
    Result := 20;
  end;
end;

function SizeUIntDecimalLen(const aValue: SizeUInt): Integer; inline;
begin
{$IF DEFINED(CPU64)}
  Result := GetDecimalLen(aValue);
{$ELSEIF DEFINED(CPU32)}
  case aValue of
    0..9: Result := 1;
    10..99: Result := 2;
    100..999: Result := 3;
    1000..9999: Result := 4;
    10000..99999: Result := 5;
    100000..999999: Result := 6;
    1000000..9999999: Result := 7;
    10000000..99999999: Result := 8;
    100000000..999999999: Result := 9;
  else
    Result := 10;
  end;
{$ELSEIF DEFINED(CPU16)}
  case aValue of
    0..9: Result := 1;
    10..99: Result := 2;
    100..999: Result := 3;
    1000..9999: Result := 4;
  else
    Result := 5;
  end;
{$ELSE}
  {$FATAL Not supported}
{$ENDIF}
end;

const
  MOD100_TBL: array[0..99] of TChar2 = (
    '00', '01', '02', '03', '04', '05', '06', '07', '08', '09',
    '10', '11', '12', '13', '14', '15', '16', '17', '18', '19',
    '20', '21', '22', '23', '24', '25', '26', '27', '28', '29',
    '30', '31', '32', '33', '34', '35', '36', '37', '38', '39',
    '40', '41', '42', '43', '44', '45', '46', '47', '48', '49',
    '50', '51', '52', '53', '54', '55', '56', '57', '58', '59',
    '60', '61', '62', '63', '64', '65', '66', '67', '68', '69',
    '70', '71', '72', '73', '74', '75', '76', '77', '78', '79',
    '80', '81', '82', '83', '84', '85', '86', '87', '88', '89',
    '90', '91', '92', '93', '94', '95', '96', '97', '98', '99');

  FIRST_UINTS_HIGH = 99;
  FIRST_UINTS: array[0..FIRST_UINTS_HIGH] of string = (
     '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',  '8',  '9', '10', '11',
    '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23',
    '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34', '35',
    '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46', '47',
    '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59',
    '60', '61', '62', '63', '64', '65', '66', '67', '68', '69', '70', '71',
    '72', '73', '74', '75', '76', '77', '78', '79', '80', '81', '82', '83',
    '84', '85', '86', '87', '88', '89', '90', '91', '92', '93', '94', '95',
    '96', '97', '98', '99');

{ for internal use only }
function QWord2DecimalStr(V: QWord; p: PChar2): DWord;
var
  Q: QWord;
begin
{$IFDEF CPU64}
  repeat
    Q := V div 100;
    if Q = 0 then break;
    p^ := MOD100_TBL[V - Q * 100];
    V := Q;
    Dec(p);
  until False;
{$ELSE}
  while V > System.High(DWord) do
    begin
      Q := V div 100;
      p^ := MOD100_TBL[V - Q * 100];
      V := Q;
      Dec(p);
    end;
  repeat
    Q := DWord(V) div 100;
    if DWord(Q) = 0 then break;
    p^ := MOD100_TBL[DWord(V) - DWord(Q) * 100];
    V := DWord(Q);
    Dec(p);
  until False;
{$ENDIF}
  Result := V;
end;

{ for internal use only }
procedure Int64_ToStr(const aValue: Int64; out s: shortstring); inline;
var
  V: QWord;
  Start, Len: Integer;
begin
  Start := 1;
  if aValue < 0 then
    begin
      V := QWord(-aValue);
      Len := GetDecimalLen(V);
      System.SetLength(s, Succ(Len));
      s[Start] := '-';
      Inc(Start);
    end
  else
    begin
      V := QWord(aValue);
      Len := GetDecimalLen(V);
      System.SetLength(s, Len);
    end;
  if Boolean(Len and 1) then
    s[Start] := MOD100_TBL[QWord2DecimalStr(V, @s[Pred(System.Length(s))])][1]
  else
    PChar2(@s[Start])^ := MOD100_TBL[QWord2DecimalStr(V, @s[Pred(System.Length(s))])];
end;

function SizeUInt2DecimalStr(V: SizeUInt; p: PChar2): SizeUInt;
var
  Q: SizeUInt;
begin
  repeat
    Q := V div 100;
    if Q = 0 then break;
    p^ := MOD100_TBL[V - Q * 100];
    V := Q;
    Dec(p);
  until False;
  Result := V;
end;

function SizeUInt2Str(V: SizeUInt): string;
var
  Len: Integer;
begin
  if V <= FIRST_UINTS_HIGH then exit(FIRST_UINTS[V]);
  Len := SizeUIntDecimalLen(V);
  System.SetLength(Result, Len);
  if Boolean(Len and 1) then
    Result[1] := MOD100_TBL[QWord2DecimalStr(V, @Result[Pred(Len)])][1]
  else
    PChar2(@Result[1])^ := MOD100_TBL[QWord2DecimalStr(V, @Result[Pred(Len)])];
end;


{
  Ulf Adams, "Ryū: Fast Float-to-String Conversion",
  https://github.com/ulfjack/ryu,
  https://github.com/BeRo1985/pasdblstrutils
}
procedure Double2Str(aValue: Double; out s: shortstring; aDecimalSeparator: AnsiChar);
const
  QOne                  = QWord(1);
  DBL_MANTISSA_BITS     = 52;
  DBL_MANTISSA_IMP_BIT  = QOne shl DBL_MANTISSA_BITS;
  DBL_MANTISSA_MASK     = Pred(DBL_MANTISSA_IMP_BIT);
  DBL_EXPONENT_BITS     = 11;
  DBL_EXPONENT_MASK     = Pred(QOne shl DBL_EXPONENT_BITS);
  DBL_BIAS              = 1023;
  DBL_POW5_INV_BITCOUNT = 125;
  DBL_POW5_BITCOUNT     = 125;
  DBL_POW5_INV_TBL_SIZE = 342;
  DBL_POW5_TBL_SIZE     = 326;
  DBL_POW5_INV_SPLIT: array[0..DBL_POW5_INV_TBL_SIZE - 1, 0..1] of QWord = (
    (QWord(1),                   QWord(2305843009213693952)),(QWord(11068046444225730970),QWord(1844674407370955161)),
    (QWord(5165088340638674453), QWord(1475739525896764129)),(QWord(7821419487252849886), QWord(1180591620717411303)),
    (QWord(8824922364862649494), QWord(1888946593147858085)),(QWord(7059937891890119595), QWord(1511157274518286468)),
    (QWord(13026647942995916322),QWord(1208925819614629174)),(QWord(9774590264567735146), QWord(1934281311383406679)),
    (QWord(11509021026396098440),QWord(1547425049106725343)),(QWord(16585914450600699399),QWord(1237940039285380274)),
    (QWord(15469416676735388068),QWord(1980704062856608439)),(QWord(16064882156130220778),QWord(1584563250285286751)),
    (QWord(9162556910162266299), QWord(1267650600228229401)),(QWord(7281393426775805432), QWord(2028240960365167042)),
    (QWord(16893161185646375315),QWord(1622592768292133633)),(QWord(2446482504291369283), QWord(1298074214633706907)),
    (QWord(7603720821608101175), QWord(2076918743413931051)),(QWord(2393627842544570617), QWord(1661534994731144841)),
    (QWord(16672297533003297786),QWord(1329227995784915872)),(QWord(11918280793837635165),QWord(2126764793255865396)),
    (QWord(5845275820328197809), QWord(1701411834604692317)),(QWord(15744267100488289217),QWord(1361129467683753853)),
    (QWord(3054734472329800808), QWord(2177807148294006166)),(QWord(17201182836831481939),QWord(1742245718635204932)),
    (QWord(6382248639981364905), QWord(1393796574908163946)),(QWord(2832900194486363201), QWord(2230074519853062314)),
    (QWord(5955668970331000884), QWord(1784059615882449851)),(QWord(1075186361522890384), QWord(1427247692705959881)),
    (QWord(12788344622662355584),QWord(2283596308329535809)),(QWord(13920024512871794791),QWord(1826877046663628647)),
    (QWord(3757321980813615186), QWord(1461501637330902918)),(QWord(10384555214134712795),QWord(1169201309864722334)),
    (QWord(5547241898389809503), QWord(1870722095783555735)),(QWord(4437793518711847602), QWord(1496577676626844588)),
    (QWord(10928932444453298728),QWord(1197262141301475670)),(QWord(17486291911125277965),QWord(1915619426082361072)),
    (QWord(6610335899416401726), QWord(1532495540865888858)),(QWord(12666966349016942027),QWord(1225996432692711086)),
    (QWord(12888448528943286597),QWord(1961594292308337738)),(QWord(17689456452638449924),QWord(1569275433846670190)),
    (QWord(14151565162110759939),QWord(1255420347077336152)),(QWord(7885109000409574610), QWord(2008672555323737844)),
    (QWord(9997436015069570011), QWord(1606938044258990275)),(QWord(7997948812055656009), QWord(1285550435407192220)),
    (QWord(12796718099289049614),QWord(2056880696651507552)),(QWord(2858676849947419045), QWord(1645504557321206042)),
    (QWord(13354987924183666206),QWord(1316403645856964833)),(QWord(17678631863951955605),QWord(2106245833371143733)),
    (QWord(3074859046935833515), QWord(1684996666696914987)),(QWord(13527933681774397782),QWord(1347997333357531989)),
    (QWord(10576647446613305481),QWord(2156795733372051183)),(QWord(15840015586774465031),QWord(1725436586697640946)),
    (QWord(8982663654677661702), QWord(1380349269358112757)),(QWord(18061610662226169046),QWord(2208558830972980411)),
    (QWord(10759939715039024913),QWord(1766847064778384329)),(QWord(12297300586773130254),QWord(1413477651822707463)),
    (QWord(15986332124095098083),QWord(2261564242916331941)),(QWord(9099716884534168143), QWord(1809251394333065553)),
    (QWord(14658471137111155161),QWord(1447401115466452442)),(QWord(4348079280205103483), QWord(1157920892373161954)),
    (QWord(14335624477811986218),QWord(1852673427797059126)),(QWord(7779150767507678651), QWord(1482138742237647301)),
    (QWord(2533971799264232598), QWord(1185710993790117841)),(QWord(15122401323048503126),QWord(1897137590064188545)),
    (QWord(12097921058438802501),QWord(1517710072051350836)),(QWord(5988988032009131678), QWord(1214168057641080669)),
    (QWord(16961078480698431330),QWord(1942668892225729070)),(QWord(13568862784558745064),QWord(1554135113780583256)),
    (QWord(7165741412905085728), QWord(1243308091024466605)),(QWord(11465186260648137165),QWord(1989292945639146568)),
    (QWord(16550846638002330379),QWord(1591434356511317254)),(QWord(16930026125143774626),QWord(1273147485209053803)),
    (QWord(4951948911778577463), QWord(2037035976334486086)),(QWord(272210314680951647),  QWord(1629628781067588869)),
    (QWord(3907117066486671641), QWord(1303703024854071095)),(QWord(6251387306378674625), QWord(2085924839766513752)),
    (QWord(16069156289328670670),QWord(1668739871813211001)),(QWord(9165976216721026213), QWord(1334991897450568801)),
    (QWord(7286864317269821294), QWord(2135987035920910082)),(QWord(16897537898041588005),QWord(1708789628736728065)),
    (QWord(13518030318433270404),QWord(1367031702989382452)),(QWord(6871453250525591353), QWord(2187250724783011924)),
    (QWord(9186511415162383406), QWord(1749800579826409539)),(QWord(11038557946871817048),QWord(1399840463861127631)),
    (QWord(10282995085511086630),QWord(2239744742177804210)),(QWord(8226396068408869304), QWord(1791795793742243368)),
    (QWord(13959814484210916090),QWord(1433436634993794694)),(QWord(11267656730511734774),QWord(2293498615990071511)),
    (QWord(5324776569667477496), QWord(1834798892792057209)),(QWord(7949170070475892320), QWord(1467839114233645767)),
    (QWord(17427382500606444826),QWord(1174271291386916613)),(QWord(5747719112518849781), QWord(1878834066219066582)),
    (QWord(15666221734240810795),QWord(1503067252975253265)),(QWord(12532977387392648636),QWord(1202453802380202612)),
    (QWord(5295368560860596524), QWord(1923926083808324180)),(QWord(4236294848688477220), QWord(1539140867046659344)),
    (QWord(7078384693692692099), QWord(1231312693637327475)),(QWord(11325415509908307358),QWord(1970100309819723960)),
    (QWord(9060332407926645887), QWord(1576080247855779168)),(QWord(14626963555825137356),QWord(1260864198284623334)),
    (QWord(12335095245094488799),QWord(2017382717255397335)),(QWord(9868076196075591040), QWord(1613906173804317868)),
    (QWord(15273158586344293478),QWord(1291124939043454294)),(QWord(13369007293925138595),QWord(2065799902469526871)),
    (QWord(7005857020398200553), QWord(1652639921975621497)),(QWord(16672732060544291412),QWord(1322111937580497197)),
    (QWord(11918976037903224966),QWord(2115379100128795516)),(QWord(5845832015580669650), QWord(1692303280103036413)),
    (QWord(12055363241948356366),QWord(1353842624082429130)),(QWord(841837113407818570),  QWord(2166148198531886609)),
    (QWord(4362818505468165179), QWord(1732918558825509287)),(QWord(14558301248600263113),QWord(1386334847060407429)),
    (QWord(12225235553534690011),QWord(2218135755296651887)),(QWord(2401490813343931363), QWord(1774508604237321510)),
    (QWord(1921192650675145090), QWord(1419606883389857208)),(QWord(17831303500047873437),QWord(2271371013423771532)),
    (QWord(6886345170554478103), QWord(1817096810739017226)),(QWord(1819727321701672159), QWord(1453677448591213781)),
    (QWord(16213177116328979020),QWord(1162941958872971024)),(QWord(14873036941900635463),QWord(1860707134196753639)),
    (QWord(15587778368262418694),QWord(1488565707357402911)),(QWord(8780873879868024632), QWord(1190852565885922329)),
    (QWord(2981351763563108441), QWord(1905364105417475727)),(QWord(13453127855076217722),QWord(1524291284333980581)),
    (QWord(7073153469319063855), QWord(1219433027467184465)),(QWord(11317045550910502167),QWord(1951092843947495144)),
    (QWord(12742985255470312057),QWord(1560874275157996115)),(QWord(10194388204376249646),QWord(1248699420126396892)),
    (QWord(1553625868034358140), QWord(1997919072202235028)),(QWord(8621598323911307159), QWord(1598335257761788022)),
    (QWord(17965325103354776697),QWord(1278668206209430417)),(QWord(13987124906400001422),QWord(2045869129935088668)),
    (QWord(121653480894270168),  QWord(1636695303948070935)),(QWord(97322784715416134),   QWord(1309356243158456748)),
    (QWord(14913111714512307107),QWord(2094969989053530796)),(QWord(8241140556867935363), QWord(1675975991242824637)),
    (QWord(17660958889720079260),QWord(1340780792994259709)),(QWord(17189487779326395846),QWord(2145249268790815535)),
    (QWord(13751590223461116677),QWord(1716199415032652428)),(QWord(18379969808252713988),QWord(1372959532026121942)),
    (QWord(14650556434236701088),QWord(2196735251241795108)),(QWord(652398703163629901),  QWord(1757388200993436087)),
    (QWord(11589965406756634890),QWord(1405910560794748869)),(QWord(7475898206584884855), QWord(2249456897271598191)),
    (QWord(2291369750525997561), QWord(1799565517817278553)),(QWord(9211793429904618695), QWord(1439652414253822842)),
    (QWord(18428218302589300235),QWord(2303443862806116547)),(QWord(7363877012587619542), QWord(1842755090244893238)),
    (QWord(13269799239553916280),QWord(1474204072195914590)),(QWord(10615839391643133024),QWord(1179363257756731672)),
    (QWord(2227947767661371545), QWord(1886981212410770676)),(QWord(16539753473096738529),QWord(1509584969928616540)),
    (QWord(13231802778477390823),QWord(1207667975942893232)),(QWord(6413489186596184024), QWord(1932268761508629172)),
    (QWord(16198837793502678189),QWord(1545815009206903337)),(QWord(5580372605318321905), QWord(1236652007365522670)),
    (QWord(8928596168509315048), QWord(1978643211784836272)),(QWord(18210923379033183008),QWord(1582914569427869017)),
    (QWord(7190041073742725760), QWord(1266331655542295214)),(QWord(436019273762630246),  QWord(2026130648867672343)),
    (QWord(7727513048493924843), QWord(1620904519094137874)),(QWord(9871359253537050198), QWord(1296723615275310299)),
    (QWord(4726128361433549347), QWord(2074757784440496479)),(QWord(7470251503888749801), QWord(1659806227552397183)),
    (QWord(13354898832594820487),QWord(1327844982041917746)),(QWord(13989140502667892133),QWord(2124551971267068394)),
    (QWord(14880661216876224029),QWord(1699641577013654715)),(QWord(11904528973500979224),QWord(1359713261610923772)),
    (QWord(4289851098633925465), QWord(2175541218577478036)),(QWord(18189276137874781665),QWord(1740432974861982428)),
    (QWord(3483374466074094362), QWord(1392346379889585943)),(QWord(1884050330976640656), QWord(2227754207823337509)),
    (QWord(5196589079523222848), QWord(1782203366258670007)),(QWord(15225317707844309248),QWord(1425762693006936005)),
    (QWord(5913764258841343181), QWord(2281220308811097609)),(QWord(8420360221814984868), QWord(1824976247048878087)),
    (QWord(17804334621677718864),QWord(1459980997639102469)),(QWord(17932816512084085415),QWord(1167984798111281975)),
    (QWord(10245762345624985047),QWord(1868775676978051161)),(QWord(4507261061758077715), QWord(1495020541582440929)),
    (QWord(7295157664148372495), QWord(1196016433265952743)),(QWord(7982903447895485668), QWord(1913626293225524389)),
    (QWord(10075671573058298858),QWord(1530901034580419511)),(QWord(4371188443704728763), QWord(1224720827664335609)),
    (QWord(14372599139411386667),QWord(1959553324262936974)),(QWord(15187428126271019657),QWord(1567642659410349579)),
    (QWord(15839291315758726049),QWord(1254114127528279663)),(QWord(3206773216762499739), QWord(2006582604045247462)),
    (QWord(13633465017635730761),QWord(1605266083236197969)),(QWord(14596120828850494932),QWord(1284212866588958375)),
    (QWord(4907049252451240275), QWord(2054740586542333401)),(QWord(236290587219081897),  QWord(1643792469233866721)),
    (QWord(14946427728742906810),QWord(1315033975387093376)),(QWord(16535586736504830250),QWord(2104054360619349402)),
    (QWord(5849771759720043554), QWord(1683243488495479522)),(QWord(15747863852001765813),QWord(1346594790796383617)),
    (QWord(10439186904235184007),QWord(2154551665274213788)),(QWord(15730047152871967852),QWord(1723641332219371030)),
    (QWord(12584037722297574282),QWord(1378913065775496824)),(QWord(9066413911450387881), QWord(2206260905240794919)),
    (QWord(10942479943902220628),QWord(1765008724192635935)),(QWord(8753983955121776503), QWord(1412006979354108748)),
    (QWord(10317025513452932081),QWord(2259211166966573997)),(QWord(874922781278525018),  QWord(1807368933573259198)),
    (QWord(8078635854506640661), QWord(1445895146858607358)),(QWord(13841606313089133175),QWord(1156716117486885886)),
    (QWord(14767872471458792434),QWord(1850745787979017418)),(QWord(746251532941302978),  QWord(1480596630383213935)),
    (QWord(597001226353042382),  QWord(1184477304306571148)),(QWord(15712597221132509104),QWord(1895163686890513836)),
    (QWord(8880728962164096960), QWord(1516130949512411069)),(QWord(10793931984473187891),QWord(1212904759609928855)),
    (QWord(17270291175157100626),QWord(1940647615375886168)),(QWord(2748186495899949531), QWord(1552518092300708935)),
    (QWord(2198549196719959625), QWord(1242014473840567148)),(QWord(18275073973719576693),QWord(1987223158144907436)),
    (QWord(10930710364233751031),QWord(1589778526515925949)),(QWord(12433917106128911148),QWord(1271822821212740759)),
    (QWord(8826220925580526867), QWord(2034916513940385215)),(QWord(7060976740464421494), QWord(1627933211152308172)),
    (QWord(16716827836597268165),QWord(1302346568921846537)),(QWord(11989529279587987770),QWord(2083754510274954460)),
    (QWord(9591623423670390216), QWord(1667003608219963568)),(QWord(15051996368420132820),QWord(1333602886575970854)),
    (QWord(13015147745246481542),QWord(2133764618521553367)),(QWord(3033420566713364587), QWord(1707011694817242694)),
    (QWord(6116085268112601993), QWord(1365609355853794155)),(QWord(9785736428980163188), QWord(2184974969366070648)),
    (QWord(15207286772667951197),QWord(1747979975492856518)),(QWord(1097782973908629988), QWord(1398383980394285215)),
    (QWord(1756452758253807981), QWord(2237414368630856344)),(QWord(5094511021344956708), QWord(1789931494904685075)),
    (QWord(4075608817075965366), QWord(1431945195923748060)),(QWord(6520974107321544586), QWord(2291112313477996896)),
    (QWord(1527430471115325346), QWord(1832889850782397517)),(QWord(12289990821117991246),QWord(1466311880625918013)),
    (QWord(17210690286378213644),QWord(1173049504500734410)),(QWord(9090360384495590213), QWord(1876879207201175057)),
    (QWord(18340334751822203140),QWord(1501503365760940045)),(QWord(14672267801457762512),QWord(1201202692608752036)),
    (QWord(16096930852848599373),QWord(1921924308174003258)),(QWord(1809498238053148529), QWord(1537539446539202607)),
    (QWord(12515645034668249793),QWord(1230031557231362085)),(QWord(1578287981759648052), QWord(1968050491570179337)),
    (QWord(12330676829633449412),QWord(1574440393256143469)),(QWord(13553890278448669853),QWord(1259552314604914775)),
    (QWord(3239480371808320148), QWord(2015283703367863641)),(QWord(17348979556414297411),QWord(1612226962694290912)),
    (QWord(6500486015647617283), QWord(1289781570155432730)),(QWord(10400777625036187652),QWord(2063650512248692368)),
    (QWord(15699319729512770768),QWord(1650920409798953894)),(QWord(16248804598352126938),QWord(1320736327839163115)),
    (QWord(7551343283653851484), QWord(2113178124542660985)),(QWord(6041074626923081187), QWord(1690542499634128788)),
    (QWord(12211557331022285596),QWord(1352433999707303030)),(QWord(1091747655926105338), QWord(2163894399531684849)),
    (QWord(4562746939482794594), QWord(1731115519625347879)),(QWord(7339546366328145998), QWord(1384892415700278303)),
    (QWord(8053925371383123274), QWord(2215827865120445285)),(QWord(6443140297106498619), QWord(1772662292096356228)),
    (QWord(12533209867169019542),QWord(1418129833677084982)),(QWord(5295740528502789974), QWord(2269007733883335972)),
    (QWord(15304638867027962949),QWord(1815206187106668777)),(QWord(4865013464138549713), QWord(1452164949685335022)),
    (QWord(14960057215536570740),QWord(1161731959748268017)),(QWord(9178696285890871890), QWord(1858771135597228828)),
    (QWord(14721654658196518159),QWord(1487016908477783062)),(QWord(4398626097073393881), QWord(1189613526782226450)),
    (QWord(7037801755317430209), QWord(1903381642851562320)),(QWord(5630241404253944167), QWord(1522705314281249856)),
    (QWord(814844308661245011),  QWord(1218164251424999885)),(QWord(1303750893857992017), QWord(1949062802279999816)),
    (QWord(15800395974054034906),QWord(1559250241823999852)),(QWord(5261619149759407279), QWord(1247400193459199882)),
    (QWord(12107939454356961969),QWord(1995840309534719811)),(QWord(5997002748743659252), QWord(1596672247627775849)),
    (QWord(8486951013736837725), QWord(1277337798102220679)),(QWord(2511075177753209390), QWord(2043740476963553087)),
    (QWord(13076906586428298482),QWord(1634992381570842469)),(QWord(14150874083884549109),QWord(1307993905256673975)),
    (QWord(4194654460505726958), QWord(2092790248410678361)),(QWord(18113118827372222859),QWord(1674232198728542688)),
    (QWord(3422448617672047318), QWord(1339385758982834151)),(QWord(16543964232501006678),QWord(2143017214372534641)),
    (QWord(9545822571258895019), QWord(1714413771498027713)),(QWord(15015355686490936662),QWord(1371531017198422170)),
    (QWord(5577825024675947042), QWord(2194449627517475473)),(QWord(11840957649224578280),QWord(1755559702013980378)),
    (QWord(16851463748863483271),QWord(1404447761611184302)),(QWord(12204946739213931940),QWord(2247116418577894884)),
    (QWord(13453306206113055875),QWord(1797693134862315907)),(QWord(3383947335406624054), QWord(1438154507889852726)),
    (QWord(16482362180876329456),QWord(2301047212623764361)),(QWord(9496540929959153242), QWord(1840837770099011489)),
    (QWord(11286581558709232917),QWord(1472670216079209191)),(QWord(5339916432225476010), QWord(1178136172863367353)),
    (QWord(4854517476818851293), QWord(1885017876581387765)),(QWord(3883613981455081034), QWord(1508014301265110212)),
    (QWord(14174937629389795797),QWord(1206411441012088169)),(QWord(11611853762797942306),QWord(1930258305619341071)),
    (QWord(5600134195496443521), QWord(1544206644495472857)),(QWord(15548153800622885787),QWord(1235365315596378285)),
    (QWord(6430302007287065643), QWord(1976584504954205257)),(QWord(16212288050055383484),QWord(1581267603963364205)),
    (QWord(12969830440044306787),QWord(1265014083170691364)),(QWord(9683682259845159889), QWord(2024022533073106183)),
    (QWord(15125643437359948558),QWord(1619218026458484946)),(QWord(8411165935146048523), QWord(1295374421166787957)),
    (QWord(17147214310975587960),QWord(2072599073866860731)),(QWord(10028422634038560045),QWord(1658079259093488585)),
    (QWord(8022738107230848036), QWord(1326463407274790868)),(QWord(9147032156827446534), QWord(2122341451639665389)),
    (QWord(11006974540203867551),QWord(1697873161311732311)),(QWord(5116230817421183718), QWord(1358298529049385849)),
    (QWord(15564666937357714594),QWord(2173277646479017358)),(QWord(1383687105660440706), QWord(1738622117183213887)),
    (QWord(12174996128754083534),QWord(1390897693746571109)),(QWord(8411947361780802685), QWord(2225436309994513775)),
    (QWord(6729557889424642148), QWord(1780349047995611020)),(QWord(5383646311539713719), QWord(1424279238396488816)),
    (QWord(1235136468979721303), QWord(2278846781434382106)),(QWord(15745504434151418335),QWord(1823077425147505684)),
    (QWord(16285752362063044992),QWord(1458461940118004547)),(QWord(5649904260166615347), QWord(1166769552094403638)),
    (QWord(5350498001524674232), QWord(1866831283351045821)),(QWord(591049586477829062),  QWord(1493465026680836657)),
    (QWord(11540886113407994219),QWord(1194772021344669325)),(QWord(18673707743239135),   QWord(1911635234151470921)),
    (QWord(14772334225162232601),QWord(1529308187321176736)),(QWord(8128518565387875758), QWord(1223446549856941389)),
    (QWord(1937583260394870242), QWord(1957514479771106223)),(QWord(8928764237799716840), QWord(1566011583816884978)),
    (QWord(14521709019723594119),QWord(1252809267053507982)),(QWord(8477339172590109297), QWord(2004494827285612772)),
    (QWord(17849917782297818407),QWord(1603595861828490217)),(QWord(6901236596354434079), QWord(1282876689462792174)),
    (QWord(18420676183650915173),QWord(2052602703140467478)),(QWord(3668494502695001169), QWord(1642082162512373983)),
    (QWord(10313493231639821582),QWord(1313665730009899186)),(QWord(9122891541139893884), QWord(2101865168015838698)),
    (QWord(14677010862395735754),QWord(1681492134412670958)),(QWord(673562245690857633), QWord(1345193707530136767)));

  DBL_POW5_SPLIT:array[0..DBL_POW5_TBL_SIZE - 1, 0..1] of QWord = (
    (QWord(0),                   QWord(1152921504606846976)),(QWord(0),                   QWord(1441151880758558720)),
    (QWord(0),                   QWord(1801439850948198400)),(QWord(0),                   QWord(2251799813685248000)),
    (QWord(0),                   QWord(1407374883553280000)),(QWord(0),                   QWord(1759218604441600000)),
    (QWord(0),                   QWord(2199023255552000000)),(QWord(0),                   QWord(1374389534720000000)),
    (QWord(0),                   QWord(1717986918400000000)),(QWord(0),                   QWord(2147483648000000000)),
    (QWord(0),                   QWord(1342177280000000000)),(QWord(0),                   QWord(1677721600000000000)),
    (QWord(0),                   QWord(2097152000000000000)),(QWord(0),                   QWord(1310720000000000000)),
    (QWord(0),                   QWord(1638400000000000000)),(QWord(0),                   QWord(2048000000000000000)),
    (QWord(0),                   QWord(1280000000000000000)),(QWord(0),                   QWord(1600000000000000000)),
    (QWord(0),                   QWord(2000000000000000000)),(QWord(0),                   QWord(1250000000000000000)),
    (QWord(0),                   QWord(1562500000000000000)),(QWord(0),                   QWord(1953125000000000000)),
    (QWord(0),                   QWord(1220703125000000000)),(QWord(0),                   QWord(1525878906250000000)),
    (QWord(0),                   QWord(1907348632812500000)),(QWord(0),                   QWord(1192092895507812500)),
    (QWord(0),                   QWord(1490116119384765625)),(QWord(4611686018427387904), QWord(1862645149230957031)),
    (QWord(9799832789158199296), QWord(1164153218269348144)),(QWord(12249790986447749120),QWord(1455191522836685180)),
    (QWord(15312238733059686400),QWord(1818989403545856475)),(QWord(14528612397897220096),QWord(2273736754432320594)),
    (QWord(13692068767113150464),QWord(1421085471520200371)),(QWord(12503399940464050176),QWord(1776356839400250464)),
    (QWord(15629249925580062720),QWord(2220446049250313080)),(QWord(9768281203487539200), QWord(1387778780781445675)),
    (QWord(7598665485932036096), QWord(1734723475976807094)),(QWord(274959820560269312),  QWord(2168404344971008868)),
    (QWord(9395221924704944128), QWord(1355252715606880542)),(QWord(2520655369026404352), QWord(1694065894508600678)),
    (QWord(12374191248137781248),QWord(2117582368135750847)),(QWord(14651398557727195136),QWord(1323488980084844279)),
    (QWord(13702562178731606016),QWord(1654361225106055349)),(QWord(3293144668132343808), QWord(2067951531382569187)),
    (QWord(18199116482078572544),QWord(1292469707114105741)),(QWord(8913837547316051968), QWord(1615587133892632177)),
    (QWord(15753982952572452864),QWord(2019483917365790221)),(QWord(12152082354571476992),QWord(1262177448353618888)),
    (QWord(15190102943214346240),QWord(1577721810442023610)),(QWord(9764256642163156992), QWord(1972152263052529513)),
    (QWord(17631875447420442880),QWord(1232595164407830945)),(QWord(8204786253993389888), QWord(1540743955509788682)),
    (QWord(1032610780636961552), QWord(1925929944387235853)),(QWord(2951224747111794922), QWord(1203706215242022408)),
    (QWord(3689030933889743652), QWord(1504632769052528010)),(QWord(13834660704216955373),QWord(1880790961315660012)),
    (QWord(17870034976990372916),QWord(1175494350822287507)),(QWord(17725857702810578241),QWord(1469367938527859384)),
    (QWord(3710578054803671186), QWord(1836709923159824231)),(QWord(26536550077201078),   QWord(2295887403949780289)),
    (QWord(11545800389866720434),QWord(1434929627468612680)),(QWord(14432250487333400542),QWord(1793662034335765850)),
    (QWord(8816941072311974870), QWord(2242077542919707313)),(QWord(17039803216263454053),QWord(1401298464324817070)),
    (QWord(12076381983474541759),QWord(1751623080406021338)),(QWord(5872105442488401391), QWord(2189528850507526673)),
    (QWord(15199280947623720629),QWord(1368455531567204170)),(QWord(9775729147674874978), QWord(1710569414459005213)),
    (QWord(16831347453020981627),QWord(2138211768073756516)),(QWord(1296220121283337709), QWord(1336382355046097823)),
    (QWord(15455333206886335848),QWord(1670477943807622278)),(QWord(10095794471753144002),QWord(2088097429759527848)),
    (QWord(6309871544845715001), QWord(1305060893599704905)),(QWord(12499025449484531656),QWord(1631326116999631131)),
    (QWord(11012095793428276666),QWord(2039157646249538914)),(QWord(11494245889320060820),QWord(1274473528905961821)),
    (QWord(532749306367912313),  QWord(1593091911132452277)),(QWord(5277622651387278295), QWord(1991364888915565346)),
    (QWord(7910200175544436838), QWord(1244603055572228341)),(QWord(14499436237857933952),QWord(1555753819465285426)),
    (QWord(8900923260467641632), QWord(1944692274331606783)),(QWord(12480606065433357876),QWord(1215432671457254239)),
    (QWord(10989071563364309441),QWord(1519290839321567799)),(QWord(9124653435777998898), QWord(1899113549151959749)),
    (QWord(8008751406574943263), QWord(1186945968219974843)),(QWord(5399253239791291175), QWord(1483682460274968554)),
    (QWord(15972438586593889776),QWord(1854603075343710692)),(QWord(759402079766405302),  QWord(1159126922089819183)),
    (QWord(14784310654990170340),QWord(1448908652612273978)),(QWord(9257016281882937117), QWord(1811135815765342473)),
    (QWord(16182956370781059300),QWord(2263919769706678091)),(QWord(7808504722524468110), QWord(1414949856066673807)),
    (QWord(5148944884728197234), QWord(1768687320083342259)),(QWord(1824495087482858639), QWord(2210859150104177824)),
    (QWord(1140309429676786649), QWord(1381786968815111140)),(QWord(1425386787095983311), QWord(1727233711018888925)),
    (QWord(6393419502297367043), QWord(2159042138773611156)),(QWord(13219259225790630210),QWord(1349401336733506972)),
    (QWord(16524074032238287762),QWord(1686751670916883715)),(QWord(16043406521870471799),QWord(2108439588646104644)),
    (QWord(803757039314269066),  QWord(1317774742903815403)),(QWord(14839754354425000045),QWord(1647218428629769253)),
    (QWord(4714634887749086344), QWord(2059023035787211567)),(QWord(9864175832484260821), QWord(1286889397367007229)),
    (QWord(16941905809032713930),QWord(1608611746708759036)),(QWord(2730638187581340797), QWord(2010764683385948796)),
    (QWord(10930020904093113806),QWord(1256727927116217997)),(QWord(18274212148543780162),QWord(1570909908895272496)),
    (QWord(4396021111970173586), QWord(1963637386119090621)),(QWord(5053356204195052443), QWord(1227273366324431638)),
    (QWord(15540067292098591362),QWord(1534091707905539547)),(QWord(14813398096695851299),QWord(1917614634881924434)),
    (QWord(13870059828862294966),QWord(1198509146801202771)),(QWord(12725888767650480803),QWord(1498136433501503464)),
    (QWord(15907360959563101004),QWord(1872670541876879330)),(QWord(14553786618154326031),QWord(1170419088673049581)),
    (QWord(4357175217410743827), QWord(1463023860841311977)),(QWord(10058155040190817688),QWord(1828779826051639971)),
    (QWord(7961007781811134206), QWord(2285974782564549964)),(QWord(14199001900486734687),QWord(1428734239102843727)),
    (QWord(13137066357181030455),QWord(1785917798878554659)),(QWord(11809646928048900164),QWord(2232397248598193324)),
    (QWord(16604401366885338411),QWord(1395248280373870827)),(QWord(16143815690179285109),QWord(1744060350467338534)),
    (QWord(10956397575869330579),QWord(2180075438084173168)),(QWord(6847748484918331612), QWord(1362547148802608230)),
    (QWord(17783057643002690323),QWord(1703183936003260287)),(QWord(17617136035325974999),QWord(2128979920004075359)),
    (QWord(17928239049719816230),QWord(1330612450002547099)),(QWord(17798612793722382384),QWord(1663265562503183874)),
    (QWord(13024893955298202172),QWord(2079081953128979843)),(QWord(5834715712847682405), QWord(1299426220705612402)),
    (QWord(16516766677914378815),QWord(1624282775882015502)),(QWord(11422586310538197711),QWord(2030353469852519378)),
    (QWord(11750802462513761473),QWord(1268970918657824611)),(QWord(10076817059714813937),QWord(1586213648322280764)),
    (QWord(12596021324643517422),QWord(1982767060402850955)),(QWord(5566670318688504437), QWord(1239229412751781847)),
    (QWord(2346651879933242642), QWord(1549036765939727309)),(QWord(7545000868343941206), QWord(1936295957424659136)),
    (QWord(4715625542714963254), QWord(1210184973390411960)),(QWord(5894531928393704067), QWord(1512731216738014950)),
    (QWord(16591536947346905892),QWord(1890914020922518687)),(QWord(17287239619732898039),QWord(1181821263076574179)),
    (QWord(16997363506238734644),QWord(1477276578845717724)),(QWord(2799960309088866689), QWord(1846595723557147156)),
    (QWord(10973347230035317489),QWord(1154122327223216972)),(QWord(13716684037544146861),QWord(1442652909029021215)),
    (QWord(12534169028502795672),QWord(1803316136286276519)),(QWord(11056025267201106687),QWord(2254145170357845649)),
    (QWord(18439230838069161439),QWord(1408840731473653530)),(QWord(13825666510731675991),QWord(1761050914342066913)),
    (QWord(3447025083132431277), QWord(2201313642927583642)),(QWord(6766076695385157452), QWord(1375821026829739776)),
    (QWord(8457595869231446815), QWord(1719776283537174720)),(QWord(10571994836539308519),QWord(2149720354421468400)),
    (QWord(6607496772837067824), QWord(1343575221513417750)),(QWord(17482743002901110588),QWord(1679469026891772187)),
    (QWord(17241742735199000331),QWord(2099336283614715234)),(QWord(15387775227926763111),QWord(1312085177259197021)),
    (QWord(5399660979626290177), QWord(1640106471573996277)),(QWord(11361262242960250625),QWord(2050133089467495346)),
    (QWord(11712474920277544544),QWord(1281333180917184591)),(QWord(10028907631919542777),QWord(1601666476146480739)),
    (QWord(7924448521472040567), QWord(2002083095183100924)),(QWord(14176152362774801162),QWord(1251301934489438077)),
    (QWord(3885132398186337741), QWord(1564127418111797597)),(QWord(9468101516160310080), QWord(1955159272639746996)),
    (QWord(15140935484454969608),QWord(1221974545399841872)),(QWord(479425281859160394),  QWord(1527468181749802341)),
    (QWord(5210967620751338397), QWord(1909335227187252926)),(QWord(17091912818251750210),QWord(1193334516992033078)),
    (QWord(12141518985959911954),QWord(1491668146240041348)),(QWord(15176898732449889943),QWord(1864585182800051685)),
    (QWord(11791404716994875166),QWord(1165365739250032303)),(QWord(10127569877816206054),QWord(1456707174062540379)),
    (QWord(8047776328842869663), QWord(1820883967578175474)),(QWord(836348374198811271),  QWord(2276104959472719343)),
    (QWord(7440246761515338900), QWord(1422565599670449589)),(QWord(13911994470321561530),QWord(1778206999588061986)),
    (QWord(8166621051047176104), QWord(2222758749485077483)),(QWord(2798295147690791113), QWord(1389224218428173427)),
    (QWord(17332926989895652603),QWord(1736530273035216783)),(QWord(17054472718942177850),QWord(2170662841294020979)),
    (QWord(8353202440125167204), QWord(1356664275808763112)),(QWord(10441503050156459005),QWord(1695830344760953890)),
    (QWord(3828506775840797949), QWord(2119787930951192363)),(QWord(86973725686804766),   QWord(1324867456844495227)),
    (QWord(13943775212390669669),QWord(1656084321055619033)),(QWord(3594660960206173375), QWord(2070105401319523792)),
    (QWord(2246663100128858359), QWord(1293815875824702370)),(QWord(12031700912015848757),QWord(1617269844780877962)),
    (QWord(5816254103165035138), QWord(2021587305976097453)),(QWord(5941001823691840913), QWord(1263492066235060908)),
    (QWord(7426252279614801142), QWord(1579365082793826135)),(QWord(4671129331091113523), QWord(1974206353492282669)),
    (QWord(5225298841145639904), QWord(1233878970932676668)),(QWord(6531623551432049880), QWord(1542348713665845835)),
    (QWord(3552843420862674446), QWord(1927935892082307294)),(QWord(16055585193321335241),QWord(1204959932551442058)),
    (QWord(10846109454796893243),QWord(1506199915689302573)),(QWord(18169322836923504458),QWord(1882749894611628216)),
    (QWord(11355826773077190286),QWord(1176718684132267635)),(QWord(9583097447919099954), QWord(1470898355165334544)),
    (QWord(11978871809898874942),QWord(1838622943956668180)),(QWord(14973589762373593678),QWord(2298278679945835225)),
    (QWord(2440964573842414192), QWord(1436424174966147016)),(QWord(3051205717303017741), QWord(1795530218707683770)),
    (QWord(13037379183483547984),QWord(2244412773384604712)),(QWord(8148361989677217490), QWord(1402757983365377945)),
    (QWord(14797138505523909766),QWord(1753447479206722431)),(QWord(13884737113477499304),QWord(2191809349008403039)),
    (QWord(15595489723564518921),QWord(1369880843130251899)),(QWord(14882676136028260747),QWord(1712351053912814874)),
    (QWord(9379973133180550126), QWord(2140438817391018593)),(QWord(17391698254306313589),QWord(1337774260869386620)),
    (QWord(3292878744173340370), QWord(1672217826086733276)),(QWord(4116098430216675462), QWord(2090272282608416595)),
    (QWord(266718509671728212),  QWord(1306420176630260372)),(QWord(333398137089660265),  QWord(1633025220787825465)),
    (QWord(5028433689789463235), QWord(2041281525984781831)),(QWord(10060300083759496378),QWord(1275800953740488644)),
    (QWord(12575375104699370472),QWord(1594751192175610805)),(QWord(1884160825592049379), QWord(1993438990219513507)),
    (QWord(17318501580490888525),QWord(1245899368887195941)),(QWord(7813068920331446945), QWord(1557374211108994927)),
    (QWord(5154650131986920777), QWord(1946717763886243659)),(QWord(915813323278131534),  QWord(1216698602428902287)),
    (QWord(14979824709379828129),QWord(1520873253036127858)),(QWord(9501408849870009354), QWord(1901091566295159823)),
    (QWord(12855909558809837702),QWord(1188182228934474889)),(QWord(2234828893230133415), QWord(1485227786168093612)),
    (QWord(2793536116537666769), QWord(1856534732710117015)),(QWord(8663489100477123587), QWord(1160334207943823134)),
    (QWord(1605989338741628675), QWord(1450417759929778918)),(QWord(11230858710281811652),QWord(1813022199912223647)),
    (QWord(9426887369424876662), QWord(2266277749890279559)),(QWord(12809333633531629769),QWord(1416423593681424724)),
    (QWord(16011667041914537212),QWord(1770529492101780905)),(QWord(6179525747111007803), QWord(2213161865127226132)),
    (QWord(13085575628799155685),QWord(1383226165704516332)),(QWord(16356969535998944606),QWord(1729032707130645415)),
    (QWord(15834525901571292854),QWord(2161290883913306769)),(QWord(2979049660840976177), QWord(1350806802445816731)),
    (QWord(17558870131333383934),QWord(1688508503057270913)),(QWord(8113529608884566205), QWord(2110635628821588642)),
    (QWord(9682642023980241782), QWord(1319147268013492901)),(QWord(16714988548402690132),QWord(1648934085016866126)),
    (QWord(11670363648648586857),QWord(2061167606271082658)),(QWord(11905663298832754689),QWord(1288229753919426661)),
    (QWord(1047021068258779650), QWord(1610287192399283327)),(QWord(15143834390605638274),QWord(2012858990499104158)),
    (QWord(4853210475701136017), QWord(1258036869061940099)),(QWord(1454827076199032118), QWord(1572546086327425124)),
    (QWord(1818533845248790147), QWord(1965682607909281405)),(QWord(3442426662494187794), QWord(1228551629943300878)),
    (QWord(13526405364972510550),QWord(1535689537429126097)),(QWord(3072948650933474476), QWord(1919611921786407622)),
    (QWord(15755650962115585259),QWord(1199757451116504763)),(QWord(15082877684217093670),QWord(1499696813895630954)),
    (QWord(9630225068416591280), QWord(1874621017369538693)),(QWord(8324733676974063502), QWord(1171638135855961683)),
    (QWord(5794231077790191473), QWord(1464547669819952104)),(QWord(7242788847237739342), QWord(1830684587274940130)),
    (QWord(18276858095901949986),QWord(2288355734093675162)),(QWord(16034722328366106645),QWord(1430222333808546976)),
    (QWord(1596658836748081690), QWord(1787777917260683721)),(QWord(6607509564362490017), QWord(2234722396575854651)),
    (QWord(1823850468512862308), QWord(1396701497859909157)),(QWord(6891499104068465790), QWord(1745876872324886446)),
    (QWord(17837745916940358045),QWord(2182346090406108057)),(QWord(4231062170446641922), QWord(1363966306503817536)),
    (QWord(5288827713058302403), QWord(1704957883129771920)),(QWord(6611034641322878003), QWord(2131197353912214900)),
    (QWord(13355268687681574560),QWord(1331998346195134312)),(QWord(16694085859601968200),QWord(1664997932743917890)),
    (QWord(11644235287647684442),QWord(2081247415929897363)),(QWord(4971804045566108824), QWord(1300779634956185852)),
    (QWord(6214755056957636030), QWord(1625974543695232315)),(QWord(3156757802769657134), QWord(2032468179619040394)),
    (QWord(6584659645158423613), QWord(1270292612261900246)),(QWord(17454196593302805324),QWord(1587865765327375307)),
    (QWord(17206059723201118751),QWord(1984832206659219134)),(QWord(6142101308573311315), QWord(1240520129162011959)),
    (QWord(3065940617289251240), QWord(1550650161452514949)),(QWord(8444111790038951954), QWord(1938312701815643686)),
    (QWord(665883850346957067),  QWord(1211445438634777304)),(QWord(832354812933696334),  QWord(1514306798293471630)),
    (QWord(10263815553021896226),QWord(1892883497866839537)),(QWord(17944099766707154901),QWord(1183052186166774710)),
    (QWord(13206752671529167818),QWord(1478815232708468388)),(QWord(16508440839411459773),QWord(1848519040885585485)),
    (QWord(12623618533845856310),QWord(1155324400553490928)),(QWord(15779523167307320387),QWord(1444155500691863660)),
    (QWord(1277659885424598868), QWord(1805194375864829576)),(QWord(1597074856780748586), QWord(2256492969831036970)),
    (QWord(5609857803915355770), QWord(1410308106144398106)),(QWord(16235694291748970521),QWord(1762885132680497632)),
    (QWord(1847873790976661535), QWord(2203606415850622041)),(QWord(12684136165428883219),QWord(1377254009906638775)),
    (QWord(11243484188358716120),QWord(1721567512383298469)),(QWord(219297180166231438),  QWord(2151959390479123087)),
    (QWord(7054589765244976505), QWord(1344974619049451929)),(QWord(13429923224983608535),QWord(1681218273811814911)),
    (QWord(12175718012802122765),QWord(2101522842264768639)),(QWord(14527352785642408584),QWord(1313451776415480399)),
    (QWord(13547504963625622826),QWord(1641814720519350499)),(QWord(12322695186104640628),QWord(2052268400649188124)),
    (QWord(16925056528170176201),QWord(1282667750405742577)),(QWord(7321262604930556539), QWord(1603334688007178222)),
    (QWord(18374950293017971482),QWord(2004168360008972777)),(QWord(4566814905495150320), QWord(1252605225005607986)),
    (QWord(14931890668723713708),QWord(1565756531257009982)),(QWord(9441491299049866327), QWord(1957195664071262478)),
    (QWord(1289246043478778550), QWord(1223247290044539049)),(QWord(6223243572775861092), QWord(1529059112555673811)),
    (QWord(3167368447542438461), QWord(1911323890694592264)),(QWord(1979605279714024038), QWord(1194577431684120165)),
    (QWord(7086192618069917952), QWord(1493221789605150206)),(QWord(18081112809442173248),QWord(1866527237006437757)),
    (QWord(13606538515115052232),QWord(1166579523129023598)),(QWord(7784801107039039482), QWord(1458224403911279498)),
    (QWord(507629346944023544),  QWord(1822780504889099373)),(QWord(5246222702107417334), QWord(2278475631111374216)),
    (QWord(3278889188817135834), QWord(1424047269444608885)),(QWord(8710297504448807696), QWord(1780059086805761106)));

type
  TDecimalRep = record
    Mantissa: QWord;
    Exponent: Integer;
  end;

  function ToDecimal(const aMantissa: QWord; const aExponent: DWord): TDecimalRep;
  var
    m2, mv, vr, vp, vm, vpDiv, vmDiv, vrDiv: QWord;
    mmShift, mvMod5: DWord;
    e2, e10, k, i, j, q, Removed: Integer;
    LastRemoved: Byte;
    AcceptBounds, vmIsTrailZeros, vrIsTrailZeros, RoundUp: Boolean;
  begin
    if aExponent = 0 then
      begin
        e2 := 1 - (DBL_BIAS + DBL_MANTISSA_BITS + 2);
        m2 := aMantissa;
      end
    else
      begin
        e2 := aExponent - (DBL_BIAS + DBL_MANTISSA_BITS + 2);
        m2 := aMantissa or DBL_MANTISSA_IMP_BIT;
      end;
    AcceptBounds := m2 and 1 = 0;
    mv := m2 * 4;
    mmShift := DWord((aMantissa <> 0) or (aExponent <= 1));
    vmIsTrailZeros := False;
    vrIsTrailZeros := False;
    if e2 >= 0 then
      begin
        q := Log10Pow2(e2) - Ord(e2 > 3);
        e10 := q;
        k := Pow5Bits(q) + DBL_POW5_INV_BITCOUNT - 1;
        i := q + k - e2;
        vr := MulShiftAll64(m2, @DBL_POW5_INV_SPLIT[q], i, vp, vm, mmShift);
        if q <= 21 then
          begin
            mvMod5 := mv - (mv div 5) * 5;
            if mvMod5 = 0 then
              vrIsTrailZeros := MultipleOfPowerOf5(mv, q)
            else
              if AcceptBounds then
                vmIsTrailZeros := MultipleOfPowerOf5(mv - Succ(mmShift), q)
              else
                Dec(vp, DWord(MultipleOfPowerOf5(mv + 2, q)));
          end;
      end
    else
      begin
        q := Log10Pow5(-e2) - Ord(-e2 > 1);
        e10 := q + e2;
        i := -e2 - q;
        k := Pow5bits(i) - DBL_POW5_BITCOUNT;
        j := q - k;
        vr := MulShiftAll64(m2, @DBL_POW5_SPLIT[i], j, vp, vm, mmShift);
        if q <= 1 then
          begin
            vrIsTrailZeros := True;
            if AcceptBounds then
              vmIsTrailZeros := mmShift = 1
            else
              Dec(vp);
          end
        else
          if q < 63 then
            vrIsTrailZeros := MultipleOfPowerOf2(mv, q);
      end;
    Removed := 0;
    LastRemoved := 0;
    if vmIsTrailZeros or vrIsTrailZeros then
      begin
        repeat
          vpDiv := vp div 10;
          vmDiv := vm div 10;
          if vpDiv <= vmDiv then break;
          vrDiv := vr div 10;
          vmIsTrailZeros := vmIsTrailZeros and (vm - vmDiv * 10 = 0);
          vrIsTrailZeros := vrIsTrailZeros and (LastRemoved = 0);
          LastRemoved := Byte(vr - vrDiv * 10);
          vr := vrDiv;
          vp := vpDiv;
          vm := vmDiv;
          Inc(Removed);
        until False;
        if vmIsTrailZeros then
          repeat
           vmDiv := vm div 10;
           if vm - 10 * vmDiv <> 0 then break;
           vpDiv := vp div 10;
           vrDiv := vr div 10;
           vrIsTrailZeros := vrIsTrailZeros and (LastRemoved = 0);
           LastRemoved := Byte(vr - vrDiv * 10);
           vr := vrDiv;
           vp := vpDiv;
           vm := vmDiv;
           Inc(Removed);
          until False;
        if vrIsTrailZeros and (LastRemoved = 5) and (vr and 1 = 0) then
          LastRemoved := 4;
        Result.Mantissa := vr + QWord((vr = vm)and not(acceptBounds and vmIsTrailZeros)or(LastRemoved >= 5));
      end
    else
      begin
        RoundUp := False;
        vpDiv := vp div 100;
        vmDiv := vm div 100;
        if vpDiv > vmDiv then
          begin
            vrDiv := vr div 100;
            RoundUp := vr - vrDiv * 100 >= 50;
            vr := vrDiv;
            vp := vpDiv;
            vm := vmDiv;
            Inc(Removed, 2);
          end;
        repeat
          vpDiv := vp div 10;
          vmDiv := vm div 10;
          if vpDiv <= vmDiv then break;
          vrDiv := vr div 10;
          RoundUp := vr - vrDiv * 10 >= 5;
          vr := vrDiv;
          vp := vpDiv;
          vm := vmDiv;
          Inc(Removed);
        until False;
        Result.Mantissa := vr + QWord((vr = vm) or RoundUp);
      end;
    Result.Exponent := e10 + Removed;
  end;
var
  Dr: TDecimalRep;
  Bits: QWord absolute aValue;
  IeeeMantissa, OutVal: QWord;
  IeeeExp: DWord;
  Len, OutLen, I, Anchor, Exponent: Integer;
  I64: Int64;
  c2: TChar2;
  Tmp: array[0..21] of AnsiChar;
  IsNeg: Boolean;
begin
  IsNeg := Boolean(Bits shr (DBL_MANTISSA_BITS + DBL_EXPONENT_BITS));
  IeeeMantissa := Bits and DBL_MANTISSA_MASK;
  IeeeExp := DWord((Bits shr DBL_MANTISSA_BITS) and DBL_EXPONENT_MASK);
  if(IeeeExp = DBL_EXPONENT_MASK) or ((IeeeExp = 0) and (IeeeMantissa = 0))then
    begin
      if IeeeMantissa <> 0 then
        begin
          s := 'NaN';
          exit;
        end;
      if IeeeExp <> 0 then
        begin
          if IsNeg then
            s := '-Infinity'
          else
            s := 'Infinity';
          exit;
        end;
      if IsNeg then
        s := '-0'
      else
        s := '0';
      exit;
    end;

  if IsExactInt(aValue, I64) then
    begin
      Int64_ToStr(I64, s);
      exit;
    end;

  Len := 0;
  Dr := ToDecimal(IeeeMantissa, IeeeExp);
  System.SetLength(s, 255);
  if IsNeg then
    begin
      s[Len+1] := '-';
      Inc(Len);
    end;
  OutVal := Dr.Mantissa;
  OutLen := GetDecimalLen(Dr.Mantissa);
  Exponent := Pred(Dr.Exponent + OutLen);
  if (Exponent < -3) or (Exponent > 15) then
    begin
      if OutLen > 1 then
        begin
          Anchor := Succ(Len);
          Inc(Len, Succ(OutLen));
          if Boolean(OutLen and 1) then
            s[Anchor] := MOD100_TBL[QWord2DecimalStr(OutVal, @s[Len-1])][1]
          else
            begin
              c2 := MOD100_TBL[QWord2DecimalStr(OutVal, @s[Len-1])];
              s[Anchor] := c2[0];
              s[Anchor+2] := c2[1];
            end;
          s[Anchor+1] := aDecimalSeparator;
        end
      else
        begin
          s[Len+1] := MOD100_TBL[OutVal][1];
          Inc(Len);
        end;
      s[Len+1] := 'E';
      Inc(Len);
      if Exponent < 0 then
        begin
          s[Len+1] := '-';
          Exponent := -Exponent;
          Inc(Len);
        end;
      OutLen := GetDecimalLen(Exponent);
      Inc(Len, OutLen);
      case OutLen of
        1: s[Len] := MOD100_TBL[Exponent][1];
        2: PChar2(@s[Len-1])^ := MOD100_TBL[Exponent];
        3:
         begin
           I := Exponent div 100;
           PChar2(@s[Len-1])^ := MOD100_TBL[Exponent - I * 100];
           s[Len-2] := MOD100_TBL[I][1];
         end;
      else
      end;
    end
  else
    if Exponent < 0 then
      begin
        s[Len+1] := '0';
        s[Len+2] := aDecimalSeparator;
        Len += 2;
        Inc(Exponent);
        while Exponent < 0 do
          begin
            s[Len+1] := '0';
            Inc(Exponent);
            Inc(Len);
          end;
        I := Succ(Len);
        Inc(Len, OutLen);
        if Boolean(OutLen and 1) then
          s[I] := MOD100_TBL[QWord2DecimalStr(OutVal, @s[Len-1])][1]
        else
          PChar2(@s[I])^ := MOD100_TBL[QWord2DecimalStr(OutVal, @s[Len-1])];
      end
    else
      if Exponent < Pred(OutLen) then
        begin
          Exponent += Succ(Len);
          Inc(Len);
          if Boolean(OutLen and 1) then
            Tmp[0] := MOD100_TBL[QWord2DecimalStr(OutVal, @Tmp[OutLen-2])][1]
          else
            PChar2(@Tmp[0])^ := MOD100_TBL[QWord2DecimalStr(OutVal, @Tmp[OutLen-2])];
          for I := Len to Exponent do
            s[I] := Tmp[I - Len];
          s[Exponent+1] := aDecimalSeparator;
          for I := Exponent+2 to Len + OutLen do
            s[I] := Tmp[Pred(I - Len)];
          Len += OutLen;
        end
      else
        begin
          I := Succ(Len);
          Len += OutLen;
          if Boolean(OutLen and 1) then
            s[I] := MOD100_TBL[QWord2DecimalStr(OutVal, @s[Len-1])][1]
          else
            PChar2(@s[I])^ := MOD100_TBL[QWord2DecimalStr(OutVal, @s[Len-1])];
          for I := Succ(Len) to Len + Succ(Exponent - OutLen) do
            s[I] := '0';
          Len += Succ(Exponent - OutLen);
          s[Len+1] := aDecimalSeparator;
          s[Len+2] := '0';
          Len += 2;
        end;
  System.SetLength(s, Len);
end;
{$POP}

function Double2Str(aValue: Double; aDecimalSeparator: AnsiChar): string;
var
  s: shortstring;
begin
  Result := '';
  Double2Str(aValue, s, aDecimalSeparator);
  System.SetLength(Result, System.Length(s));
  System.Move(s[1], Pointer(Result)^, System.Length(s));
end;

function Double2StrDef(aValue: Double): string;
begin
  Result := Double2Str(aValue, DefaultFormatSettings.DecimalSeparator);
end;

function TJsonNode.DoBuildJson: TStrBuilder;
var
  sb: TStrBuilder;
  e: TPair;
  s: shortstring;
  procedure BuildJson(aInst: TJsonNode);
  var
    I, Last: SizeInt;
  begin
    case aInst.Kind of
      jvkNull:   sb.Append(JS_NULL);
      jvkFalse:  sb.Append(JS_FALSE);
      jvkTrue:   sb.Append(JS_TRUE);
      jvkNumber:
        begin
          Double2Str(aInst.FValue.Num, s);
          sb.Append(s);
        end;
      jvkString: sb.AppendEncode(aInst.FString);
      jvkArray:
        begin
          sb.Append(chOpenSqrBr);
          if aInst.FArray <> nil then
            begin
              Last := Pred(aInst.FArray^.Count);
              for I := 0 to Last do
                begin
                  BuildJson(aInst.FArray^.UncMutable[I]^);
                  if I <> Last then
                    sb.Append(chComma);
                end;
            end;
          sb.Append(chClosSqrBr);
        end;
      jvkObject:
        begin
          sb.Append(chOpenCurBr);
          if aInst.FObject <> nil then
            begin
              Last := Pred(aInst.FObject^.Count);
              for I := 0 to Last do
                begin
                  e := aInst.FObject^.Mutable[I]^;
                  sb.AppendEncode(e.Key);
                  sb.Append(chColon);
                  BuildJson(e.Value);
                  if I <> Last then
                    sb.Append(chComma);
                end;
            end;
          sb.Append(chClosCurBr);
        end;
    else
    end;
  end;
begin
  sb := TStrBuilder.Create(S_BUILD_INIT_SIZE);
  BuildJson(Self);
  Result := sb;
end;

function TJsonNode.GetAsJson: string;
begin
  Result := DoBuildJson.ToString;
end;

procedure TJsonNode.SetAsJson(const aValue: string);
begin
  if not Parse(aValue) then
    raise EJsException.Create(SECantParseJsStr);
end;

function TJsonNode.GetCount: SizeInt;
begin
  case Kind of
    jvkUnknown, jvkNull, jvkFalse, jvkTrue, jvkNumber, jvkString: ;
    jvkArray:  if FArray <> nil then exit(FArray^.Count);
    jvkObject: if FObject <> nil then exit(FObject^.Count);
  end;
  Result := 0;
end;

function TJsonNode.CanArrayInsert(aIndex: SizeInt): Boolean;
begin
  if aIndex <> 0 then
    exit((Kind = jvkArray)and(FValue.Ref <> nil)and(SizeUInt(aIndex) <= SizeUInt(FArray^.Count)));
  if AsArray.FValue.Ref = nil then
    FValue.Ref := CreateJsArray;
  Result := True;
end;

function TJsonNode.CanObjectInsert(aIndex: SizeInt): Boolean;
begin
  if aIndex <> 0 then
    exit((Kind = jvkObject)and(FValue.Ref <> nil)and(SizeUInt(aIndex) <= SizeUInt(FObject^.Count)));
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  Result := True;
end;

function TJsonNode.GetItem(aIndex: SizeInt): TJsonNode;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    case Kind of
      jvkArray:  exit(FArray^.UncMutable[aIndex]^);
      jvkObject: exit(FObject^.Mutable[aIndex]^.Value);
    else
    end
  else
    raise EJsException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
  Result := nil;
end;

function TJsonNode.GetPair(aIndex: SizeInt): TPair;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    if Kind = jvkObject then
      exit(FObject^.Mutable[aIndex]^)
    else
      raise EJsException.Create(SEJsonInstNotObj)
  else
    raise EJsException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
  Result := Default(TPair);
end;

function TJsonNode.GetByName(const aName: string): TJsonNode;
begin
  FindOrAdd(aName, Result);
end;

function TJsonNode.GetValue(const aName: string): TJVariant;
var
  Node: TJsonNode;
begin
  if Find(aName, Node) then
    case Node.Kind of
      jvkUnknown,
      jvkNull:   exit(TJVariant.Null);
      jvkFalse:  exit(False);
      jvkTrue:   exit(True);
      jvkNumber: exit(Node.FValue.Num);
      jvkString: exit(Node.FString);
      jvkArray:  raise EJsException.CreateFmt(SECantConvertFmt, ['Array', 'TJVariant']);
      jvkObject: raise EJsException.CreateFmt(SECantConvertFmt, ['Object', 'TJVariant']);
    end
  else
    raise EJsException.Create(SEValueNotFound);
  Result.Clear;
end;

procedure TJsonNode.SetValue(const aName: string; const aValue: TJVariant);
var
  Node: TJsonNode;
begin
  FindOrAdd(aName, Node);
  case aValue.Kind of
    vkNull:   Node.AsNull;
    vkBool:   Node.AsBoolean := aValue.AsBoolean;
    vkNumber: Node.AsNumber := aValue.AsNumber;
    vkString: Node.AsString := aValue.AsString;
  end;
end;

procedure TJsonNode.SetNArray(const aName: string; const aValue: TJVarArray);
var
  Node: TJsonNode;
begin
  if FindOrAdd(aName, Node) then
    begin
      Node.DoClear;
      Node.FKind := jvkArray;
    end;
  Node.Add(aValue);
end;

procedure TJsonNode.SetNObject(const aName: string; const aValue: TJPairArray);
var
  Node: TJsonNode;
begin
  if FindOrAdd(aName, Node) then
    begin
      Node.DoClear;
      Node.FKind := jvkObject;
    end;
  Node.Add(aValue);
end;

{ TJsonNode.TNodeEnumerator }

function TJsonNode.TNodeEnumerator.GetCurrent: TVisitNode;
begin
  Result := FCurrent;
end;

constructor TJsonNode.TNodeEnumerator.Create(aNode: TJsonNode);
begin
  FStart := TVisitNode.Init(aNode);
  FQueue.Enqueue(FStart);
end;

function TJsonNode.TNodeEnumerator.MoveNext: Boolean;
var
  I: SizeInt;
begin
  if FQueue.TryDequeue(FCurrent) then
    begin
      case FCurrent.Node.Kind of
        jvkArray:
          if FCurrent.Node.FArray <> nil then
            for I := 0 to Pred(FCurrent.Node.FArray^.Count) do
              FQueue.Enqueue(TVisitNode.Init(
                 Succ(FCurrent.Level), I, FCurrent.Node, FCurrent.Node.FArray^.UncMutable[I]^));
        jvkObject:
          if FCurrent.Node.FObject <> nil then
            for I := 0 to Pred(FCurrent.Node.FObject^.Count) do
              with FCurrent.Node.FObject^.Mutable[I]^ do
                FQueue.Enqueue(TVisitNode.Init(Succ(FCurrent.Level), Key, FCurrent.Node, Value));
      else
      end;
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.GetNodeEnumerable: INodeEnumerable;
begin
  Result := specialize TGEnumCursor<TVisitNode>.Create(TNodeEnumerator.Create(Self));
end;

class function TJsonNode.ValidJson(const s: string; aDepth: Integer; aSkipBom: Boolean): Boolean;
var
  Stack: array[0..DEF_DEPTH] of TParseMode;
  DynStack: array of TParseMode = nil;
  Buf: PByte;
  Size: SizeInt;
begin
  if aDepth < 1 then exit(False);
  Buf := Pointer(s);
  Size := System.Length(s);
  if Size < 1 then exit(False);
  if aSkipBom then
    case DetectBom(Buf, Size) of
      bkNone: ;
      bkUtf8:
        begin
          Buf += UTF8_BOM_LEN;
          Size -= UTF8_BOM_LEN;
        end;
    else
      exit(False);
    end;
  if aDepth <= DEF_DEPTH then
    Result := ValidateBuf(Buf, Size, TOpenArray.Create(@Stack[0], aDepth + 1))
  else
    begin
      System.SetLength(DynStack, aDepth + 1);
      Result := ValidateBuf(Buf, Size, TOpenArray.Create(Pointer(DynStack), aDepth + 1))
    end;
end;

class function TJsonNode.ValidJson(aStream: TStream; aDepth: Integer; aSkipBom: Boolean): Boolean;
var
  Stack: array[0..DEF_DEPTH] of TParseMode;
  DynStack: array of TParseMode = nil;
begin
  if aDepth < 1 then exit(False);
  if aDepth <= DEF_DEPTH then
    Result := ValidateStream(aStream, aSkipBom, TOpenArray.Create(@Stack[0], aDepth + 1))
  else
    begin
      System.SetLength(DynStack, aDepth + 1);
      Result := ValidateStream(aStream, aSkipBom, TOpenArray.Create(Pointer(DynStack), aDepth + 1));
    end;
end;

class function TJsonNode.ValidJson(aStream: TStream; aCount: SizeInt; aDepth: Integer;
  aSkipBom: Boolean): Boolean;
var
  s: string;
begin
  with TStringStream.Create do
    try
      CopyFrom(aStream, aCount);
      s := DataString;
    finally
      Free;
    end;
  Result := ValidJson(s, aDepth, aSkipBom);
end;

class function TJsonNode.ValidJsonFile(const aFileName: string; aDepth: Integer;
  aSkipBom: Boolean): Boolean;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(aFileName, fmOpenRead);
  try
    Result := ValidJson(fs, aDepth, aSkipBom);
  finally
    fs.Free;
  end;
end;

class function TJsonNode.JsonStringValid(const s: string): Boolean;
var
  Stack: array[0..3] of TParseMode;
begin
  if System.Length(s) < 2 then
    exit(False);
  Result := ValidateStrBuf(Pointer(s), System.Length(s), TOpenArray.Create(@Stack[0], 1));
end;

class function TJsonNode.JsonNumberValid(const s: string): Boolean;
var
  Stack: array[0..3] of TParseMode;
begin
  if System.Length(s) < 1 then
    exit(False);
  Result := ValidateNumBuf(Pointer(s), System.Length(s), TOpenArray.Create(@Stack[0], 1));
end;

class function TJsonNode.LikelyKind(aBuf: PAnsiChar; aSize: SizeInt): TJsValueKind;
var
  I: SizeInt;
begin
  Result := jvkUnknown;
  for I := 0 to Pred(aSize) do
    case aBuf[I] of
      #9, #10, #13, ' ': ;
      '"':               exit(jvkString);
      '-', '0'..'9':     exit(jvkNumber);
      '[':               exit(jvkArray);
      '{':               exit(jvkObject);
      'f':               exit(jvkFalse);
      'n':               exit(jvkNull);
      't':               exit(jvkTrue);
    end;
end;

function DoParseStr(Buf: PAnsiChar; Size: SizeInt; aNode: TJsonNode; const aStack: TOpenArray): Boolean; forward;

type
  TParseNode = record
    Node: TJsonNode;
    Mode: TParseMode;
    constructor Create(aNode: TJsonNode; aMode: TParseMode);
  end;
  PParseNode = ^TParseNode;

constructor TParseNode.Create(aNode: TJsonNode; aMode: TParseMode);
begin
  Node := aNode;
  Mode := aMode;
end;

class function TJsonNode.TryParse(const s: string; out aRoot: TJsonNode; aDepth: Integer;
  aSkipBom: Boolean): Boolean;
var
  Stack: array[0..DEF_DEPTH] of TParseNode;
  DynStack: array of TParseNode = nil;
  Buf: PAnsiChar;
  Size: SizeInt;
begin
  aRoot := nil;
  if aDepth < 1 then exit(False);
  Buf := Pointer(s);
  Size := System.Length(s);
  if Size < 1 then exit(False);
  if aSkipBom then
    case DetectBom(Pointer(Buf), Size) of
      bkNone: ;
      bkUtf8:
        begin
          Buf += UTF8_BOM_LEN;
          Size -= UTF8_BOM_LEN;
        end;
    else
      exit(False);
    end;
  aRoot := TJsonNode.Create;
  try
    if aDepth <= DEF_DEPTH then
      Result :=
        DoParseStr(Buf, Size, aRoot, TOpenArray.Create(@Stack[0], aDepth + 1))
    else
      begin
        System.SetLength(DynStack, aDepth + 1);
        Result :=
          DoParseStr(Buf, Size, aRoot, TOpenArray.Create(Pointer(DynStack), aDepth + 1));
      end;
  except
    Result := False;
  end;
  if not Result then
    FreeAndNil(aRoot);
end;

class function TJsonNode.TryParse(aStream: TStream; out aRoot: TJsonNode; aDepth: Integer;
  aSkipBom: Boolean): Boolean;
var
  s: string = '';
begin
  System.SetLength(s, aStream.Size - aStream.Position);
  aStream.ReadBuffer(Pointer(s)^, System.Length(s));
  Result := TryParse(s, aRoot, aDepth, aSkipBom);
end;

class function TJsonNode.TryParse(aStream: TStream; aCount: SizeInt; out aRoot: TJsonNode;
  aDepth: Integer; aSkipBom: Boolean): Boolean;
var
  s: string = '';
begin
  with TStringStream.Create do
    try
      CopyFrom(aStream, aCount);
      s := DataString;
    finally
      Free;
    end;
  Result := TryParse(s, aRoot, aDepth, aSkipBom);
end;

class function TJsonNode.TryParseFile(const aFileName: string; out aRoot: TJsonNode;
  aDepth: Integer; aSkipBom: Boolean): Boolean;
var
  s: string = '';
begin
  with TFileStream.Create(aFileName, fmOpenRead or fmShareDenyWrite) do
    try
      System.SetLength(s, Size);
      ReadBuffer(Pointer(s)^, System.Length(s)); //todo: Size > MaxInt ???
    finally
      Free;
    end;
  Result := TryParse(s, aRoot, aDepth, aSkipBom);
end;

class function TJsonNode.Load(const s: string; aDepth: Integer; aSkipBom: Boolean): TJsonNode;
begin
  TryParse(s, Result, aDepth, aSkipBom);
end;

class function TJsonNode.Load(aStream: TStream; aDepth: Integer; aSkipBom: Boolean): TJsonNode;
begin
  TryParse(aStream, Result, aDepth, aSkipBom);
end;

class function TJsonNode.Load(aStream: TStream; aCount: SizeInt; aDepth: Integer; aSkipBom: Boolean): TJsonNode;
begin
  TryParse(aStream, aCount, Result, aDepth, aSkipBom);
end;

class function TJsonNode.LoadFromFile(const aFileName: string; aDepth: Integer; aSkipBom: Boolean): TJsonNode;
begin
  TryParseFile(aFileName, Result, aDepth, aSkipBom);
end;

class function TJsonNode.PasStrToJson(const s: string): string;
var
  sb: TStrBuilder;
begin
  Result := '';
  sb := TStrBuilder.Create(System.Length(s)*2);
  sb.AppendEncode(s);
  Result := sb.ToString;
end;

class function TJsonNode.NewNode: TJsonNode;
begin
  Result := TJsonNode.Create;
end;

class function TJsonNode.NewNull: TJsonNode;
begin
  Result := TJsonNode.CreateNull;
end;

class function TJsonNode.NewNode(aValue: Boolean): TJsonNode;
begin
  Result := TJsonNode.Create(aValue);
end;

class function TJsonNode.NewNode(aValue: Double): TJsonNode;
begin
  Result := TJsonNode.Create(aValue);
end;

class function TJsonNode.NewNode(const aValue: string): TJsonNode;
begin
  Result := TJsonNode.Create(aValue);
end;

class function TJsonNode.NewNode(aKind: TJsValueKind): TJsonNode;
begin
  Result := TJsonNode.Create(aKind);
end;

class function TJsonNode.NewNode(aNode: TJsonNode): TJsonNode;
begin
  Result := aNode.Clone;
end;

class function TJsonNode.NewJson(const s: string): TJsonNode;
begin
  TryParse(s, Result);
end;

class function TJsonNode.MaxNestDepth(aNode: TJsonNode): SizeInt;
var
  MaxDep: SizeInt = 0;
  procedure Traverse(aNode: TJsonNode; aLevel: SizeInt);
  var
    I: SizeInt;
  begin
    if aLevel > MaxDep then
      MaxDep := aLevel;
    if aNode.Count > 0 then
      case aNode.Kind of
        jvkArray:
          for I := 0 to Pred(aNode.FArray^.Count) do
            Traverse(aNode.FArray^.UncMutable[I]^, Succ(aLevel));
        jvkObject:
          for I := 0 to Pred(aNode.FObject^.Count) do
            Traverse(aNode.FObject^.Mutable[I]^.Value, Succ(aLevel));
      else
      end;
  end;
begin
  Traverse(aNode, 0);
  Result := MaxDep;
end;

class function TJsonNode.DupeNamesFree(aNode: TJsonNode): Boolean;
  function NamesUnique(aNode: TJsonNode): Boolean;
  var
    I: SizeInt;
  begin
    if aNode.Count > 0 then
      case aNode.Kind of
        jvkArray:
          for I := 0 to Pred(aNode.Count) do
            if not NamesUnique(aNode.FArray^.UncMutable[I]^) then
              exit(False);
        jvkObject:
          for I := 0 to Pred(aNode.Count) do
            with aNode.FObject^.Mutable[I]^ do
              begin
                if not aNode.FObject^.HasUniqKey(I) then
                  exit(False);
                if not NamesUnique(Value) then
                  exit(False);
              end;
      else
      end;
    Result := True;
  end;
begin
  Result := NamesUnique(aNode);
end;

class function TJsonNode.Equal(L, R: TJsonNode): Boolean;
begin
  Result := L.EqualTo(R);
end;

class function TJsonNode.HashCode(aNode: TJsonNode): SizeInt;
begin
  Result := aNode.HashCode;
end;

constructor TJsonNode.Create;
begin
  Assert(Kind = jvkUnknown);
end;

constructor TJsonNode.CreateNull;
begin
  FKind := jvkNull;
end;

constructor TJsonNode.Create(aValue: Boolean);
begin
  if aValue then
    FKind := jvkTrue
  else
    FKind := jvkFalse;
end;

constructor TJsonNode.Create(aValue: Double);
begin
  FValue.Num := aValue;
  FKind := jvkNumber;
end;

constructor TJsonNode.Create(const aValue: string);
begin
  FString := aValue;
  FKind := jvkString;
end;

constructor TJsonNode.Create(aKind: TJsValueKind);
begin
  FKind := aKind;
end;

constructor TJsonNode.Create(const a: TJVarArray);
var
  I: SizeInt;
begin
  FValue.Ref := CreateJsArray;
  FKind := jvkArray;
  for I := 0 to System.High(a) do
    case a[I].Kind of
      vkNull:   FArray^.Add(TJsonNode.CreateNull);
      vkBool:   FArray^.Add(TJsonNode.Create(Boolean(a[I])));
      vkNumber: FArray^.Add(TJsonNode.Create(Double(a[I])));
      vkString: FArray^.Add(TJsonNode.Create(string(a[I])));
    end;
end;

constructor TJsonNode.Create(const a: TJPairArray);
var
  I: SizeInt;
begin
  FValue.Ref := CreateJsObject;
  FKind := jvkObject;
  for I := 0 to System.High(a) do
    with a[I] do
      case Value.Kind of
        vkNull:   FObject^.Add(TPair.Create(Key, TJsonNode.CreateNull));
        vkBool:   FObject^.Add(TPair.Create(Key, TJsonNode.Create(Boolean(Value))));
        vkNumber: FObject^.Add(TPair.Create(Key, TJsonNode.Create(Double(Value))));
        vkString: FObject^.Add(TPair.Create(Key, TJsonNode.Create(string(Value))));
      end;
end;

constructor TJsonNode.Create(aNode: TJsonNode);
begin
  Create;
  CopyFrom(aNode);
end;

destructor TJsonNode.Destroy;
begin
  DoClear;
  inherited;
end;

function TJsonNode.GetEnumerator: TEnumerator;
begin
  Result.FNode := Self;
  Result.FCurrIndex := NULL_INDEX;
end;

function TJsonNode.SubTree: TSubTree;
begin
  Result.FNode := Self;
end;

function TJsonNode.Enrties: TEntries;
begin
  Result.FNode := Self;
end;

function TJsonNode.Names: TNames;
begin
  Result.FNode := Self;
end;

function TJsonNode.EqualNames(const aName: string): IPairEnumerable;
begin
  if (Kind = jvkObject) and (FValue.Ref <> nil) then
    exit(TPairs.Create(TEqualEnumerator.Create(FObject^.GetEqualEnumerator(aName))));
  Result := TPairs.Create(TEmptyPairEnumerator.Create);
end;

function TJsonNode.IsNull: Boolean;
begin
  Result := Kind = jvkNull;
end;

function TJsonNode.IsFalse: Boolean;
begin
  Result := Kind = jvkFalse;
end;

function TJsonNode.IsTrue: Boolean;
begin
  Result := Kind = jvkTrue;
end;

function TJsonNode.IsNumber: Boolean;
begin
  Result := Kind = jvkNumber;
end;

function TJsonNode.IsInteger: Boolean;
begin
  if Kind <> jvkNumber then
    exit(False);
  Result := IsExactInt(FValue.Num);
end;

function TJsonNode.IsString: Boolean;
begin
  Result := Kind = jvkString;
end;

function TJsonNode.IsBoolean: Boolean;
begin
  Result := Kind in [jvkFalse, jvkTrue];
end;

function TJsonNode.IsArray: Boolean;
begin
  Result := Kind = jvkArray;
end;

function TJsonNode.IsObject: Boolean;
begin
  Result := Kind = jvkObject;
end;

function TJsonNode.IsLiteral: Boolean;
begin
  Result := Kind in [jvkNull, jvkFalse, jvkTrue];
end;

function TJsonNode.IsScalar: Boolean;
begin
  Result := Kind in [jvkNull, jvkFalse, jvkTrue, jvkNumber, jvkString];
end;

function TJsonNode.IsStruct: Boolean;
begin
  Result := Kind in [jvkArray, jvkObject];
end;

{ TJsonNode.TEnumerator }

function TJsonNode.TEnumerator.GetCurrent: TJsonNode;
begin
  case FNode.Kind of
    jvkArray:  Result := FNode.FArray^.UncMutable[FCurrIndex]^;
    jvkObject: Result := FNode.FObject^.Mutable[FCurrIndex]^.Value;
  else
    Result := nil;
  end;
end;

function TJsonNode.TEnumerator.MoveNext: Boolean;
begin
  Inc(FCurrIndex);
  Result := FCurrIndex < FNode.Count;
end;

{ TJsonNode.TTreeEnumerator }

function TJsonNode.TTreeEnumerator.GetCurrent: TJsonNode;
begin
  Result := FCurrent;
end;

function TJsonNode.TTreeEnumerator.MoveNext: Boolean;
var
  I: SizeInt;
begin
  if FQueue.TryDequeue(FCurrent) then
    begin
      if FCurrent.Count <> 0 then
        case FCurrent.Kind of
          jvkArray:
            for I := 0 to Pred(FCurrent.FArray^.Count) do
              FQueue.Enqueue(FCurrent.FArray^.UncMutable[I]^);
          jvkObject:
            for I := 0 to Pred(FCurrent.FObject^.Count) do
              FQueue.Enqueue(FCurrent.FObject^.Mutable[I]^.Value);
        else
        end;
      exit(True);
    end;
  Result := False;
end;

{ TJsonNode.TSubTree }

function TJsonNode.TSubTree.GetEnumerator: TTreeEnumerator;
var
  Node: TJsonNode;
begin
  Result.FQueue := Default(TTreeEnumerator.TQueue);
  for Node in FNode do
    Result.FQueue.Enqueue(Node);
  Result.FCurrent := nil;
end;

{ TJsonNode.TEntryEnumerator }

function TJsonNode.TEntryEnumerator.GetCurrent: TPair;
begin
  Result := FNode.FObject^.Mutable[FCurrIndex]^
end;

function TJsonNode.TEntryEnumerator.MoveNext: Boolean;
begin
  if FNode.Kind <> jvkObject then
    exit(False);
  Inc(FCurrIndex);
  Result := FCurrIndex < FNode.Count;
end;

{ TJsonNode.TEntries }

function TJsonNode.TEntries.GetEnumerator: TEntryEnumerator;
begin
  Result.FNode := FNode;
  Result.FCurrIndex := NULL_INDEX;
end;

{ TJsonNode.TNameEnumerator }

function TJsonNode.TNameEnumerator.GetCurrent: string;
begin
  Result := FNode.FObject^.Mutable[FCurrIndex]^.Key;
end;

function TJsonNode.TNameEnumerator.MoveNext: Boolean;
begin
  if FNode.Kind <> jvkObject then
    exit(False);
  Inc(FCurrIndex);
  Result := FCurrIndex < FNode.Count;
end;

{ TJsonNode.TNames }

function TJsonNode.TNames.GetEnumerator: TNameEnumerator;
begin
  Result.FNode := FNode;
  Result.FCurrIndex := NULL_INDEX;
end;

procedure TJsonNode.Clear;
begin
  DoClear;
  FKind := jvkUnknown;
end;

function TJsonNode.Clone: TJsonNode;
begin
  Result := TJsonNode.Create;
  Result.CopyFrom(Self);
end;

procedure TJsonNode.CopyFrom(aNode: TJsonNode);
  procedure DoCopy(aSrc, aDst: TJsonNode);
  var
    I: SizeInt;
    Node: TJsonNode;
  begin
    case aSrc.Kind of
      jvkUnknown: ;
      jvkNull:    aDst.AsNull;
      jvkFalse:   aDst.AsBoolean := False;
      jvkTrue:    aDst.AsBoolean := True;
      jvkNumber:  aDst.AsNumber := aSrc.FValue.Num;
      jvkString:  aDst.AsString := aSrc.FString;
      jvkArray:
        begin
          aDst.AsArray;
          if aSrc.Count > 0 then
            begin
              aDst.FArray := CreateJsArray;
              aDst.FArray^.EnsureCapacity(aSrc.FArray^.Count);
              for I := 0 to Pred(aSrc.FArray^.Count) do
                begin
                  Node := TJsonNode.Create;
                  DoCopy(aSrc.FArray^.UncMutable[I]^, Node);
                  aDst.FArray^.Add(Node);
                end;
            end;
        end;
      jvkObject:
       begin
         aDst.AsObject;
         if aSrc.Count > 0 then
           begin
             aDst.FObject := CreateJsObject;
             aDst.FObject^.EnsureCapacity(aSrc.FObject^.Count);
             for I := 0 to Pred(aSrc.FObject^.Count) do
               begin
                 Node := TJsonNode.Create;
                 with aSrc.FObject^.Mutable[I]^ do
                   begin
                     DoCopy(Value, Node);
                     aDst.FObject^.Add(TPair.Create(Key, Node));
                   end;
               end;
           end;
       end;
    end;
  end;

begin
  if aNode = Self then
    exit;
  Clear;
  DoCopy(aNode, Self);
end;

function TJsonNode.EqualTo(aNode: TJsonNode): Boolean;
var
  I: SizeInt;
  p: ^TPair;
begin
  if Self = nil then
    exit(aNode = nil)
  else
    if aNode = nil then
      exit(False);
  if aNode = Self then
    exit(True);
  if (Kind <> aNode.Kind) or (Count <> aNode.Count) then
    exit(False);
  case aNode.Kind of
    jvkUnknown, jvkNull, jvkFalse, jvkTrue: ; //todo: jvkUnknown ???
    jvkNumber: exit(FValue.Num = aNode.FValue.Num);
    jvkString: exit(FString = aNode.FString);
    jvkArray:
      for I := 0 to Pred(Count) do
        if not FArray^.UncMutable[I]^.EqualTo(aNode.FArray^.UncMutable[I]^) then
          exit(False);
    jvkObject:
      begin
        for I := 0 to Pred(Count) do
          begin
            p := aNode.FObject^.FindUniq(FObject^.Mutable[I]^.Key);
            if p = nil then
              exit(False);
            if not FObject^.Mutable[I]^.Value.EqualTo(p^.Value) then
              exit(False);
          end;
      end;
  end;
  Result := True;
end;

{$PUSH}{$Q-}{$R-}
function TJsonNode.HashCode: SizeInt;
const
  MAGIC = SizeInt(161803398); //golden ratio
var
  I: SizeInt;
begin
  if Self = nil then
    exit(MAGIC);
  case Kind of
    jvkUnknown: Result := MAGIC + 1;
    jvkNull:    Result := MAGIC + 3;
    jvkFalse:   Result := MAGIC + 7;
    jvkTrue:    Result := MAGIC + 17;
    jvkNumber:  Result := Double.HashCode(FValue.Num);
    jvkString:  Result := string.HashCode(FString);
    jvkArray:
      begin
        Result := MAGIC + 31;
        for I := 0 to Pred(Count) do
          Result := RolSizeInt(Result + I, 13) xor FArray^.UncMutable[I]^.HashCode;
      end;
    jvkObject:
      begin
        Result := RolSizeInt(MAGIC + 67, 11);
        for I := 0 to Pred(Count) do
          with FObject^.Mutable[I]^ do
            Result := Result xor string.HashCode(Key) xor Value.HashCode;
      end;
  end;
end;
{$POP}

function TJsonNode.Parse(const s: string): Boolean;
var
  Node: TJsonNode;
begin
  if not TryParse(s, Node) then
    exit(False);
  try
    Clear;
    case Node.FKind of
      jvkNumber:
        begin
          Self.FValue.Num := Node.FValue.Num;
          Node.FValue.Int := 0;
          FKind := jvkNumber;
        end;
      jvkString:
        begin
          FString := Node.FString;
          Node.FString := '';
          FKind := jvkString;
        end;
      jvkArray:
        begin
          FArray := Node.FArray;
          Node.FArray := nil;
          FKind := jvkArray;
        end;
      jvkObject:
        begin
          FObject := Node.FObject;
          Node.FObject := nil;
          FKind := jvkObject;
        end;
    else
      FKind := Node.Kind;
    end;
    Node.FKind := jvkUnknown;
    Result := True;
  finally
    Node.Free;
  end;
end;

procedure TJsonNode.Iterate(aFunc: TOnIterate);
var
  Done: Boolean = False;
  procedure DoIterate(const aCtx: TIterContext; aNode: lgJson.TJsonNode);
  var
    I: SizeInt;
  begin
    if Done then exit;
    Done := not aFunc(aCtx, aNode);
    if Done then exit;
    case aNode.Kind of
      jvkArray:
        if aNode.FArray <> nil then
          for I := 0 to Pred(aNode.FArray^.Count) do
            begin
              DoIterate(TIterContext.Init(Succ(aCtx.Level), I, aNode), aNode.FArray^.UncMutable[I]^);
              if Done then exit;
            end;
      jvkObject:
        if aNode.FObject <> nil then
          for I := 0 to Pred(aNode.FObject^.Count) do
            with aNode.FObject^.Mutable[I]^ do
              begin
                DoIterate(TIterContext.Init(Succ(aCtx.Level), Key, aNode), Value);
                if Done then exit;
              end;
    else
    end;
  end;
begin
  if aFunc = nil then exit;
  DoIterate(TIterContext.Init(nil), Self);
end;

procedure TJsonNode.Iterate(aFunc: TNestIterate);
var
  Done: Boolean = False;
  procedure DoIterate(const aCtx: TIterContext; aNode: lgJson.TJsonNode);
  var
    I: SizeInt;
  begin
    if Done then exit;
    Done := not aFunc(aCtx, aNode);
    if Done then exit;
    case aNode.Kind of
      jvkArray:
        if aNode.FArray <> nil then
          for I := 0 to Pred(aNode.FArray^.Count) do
            begin
              DoIterate(TIterContext.Init(Succ(aCtx.Level), I, aNode), aNode.FArray^.UncMutable[I]^);
              if Done then exit;
            end;
      jvkObject:
        if aNode.FObject <> nil then
          for I := 0 to Pred(aNode.FObject^.Count) do
            with aNode.FObject^.Mutable[I]^ do
              begin
                DoIterate(TIterContext.Init(Succ(aCtx.Level), Key, aNode), Value);
                if Done then exit;
              end;
    else
    end;
  end;
begin
  if aFunc = nil then exit;
  DoIterate(TIterContext.Init(nil), Self);
end;

function TJsonNode.AddNull: TJsonNode;
begin
  if AsArray.FValue.Ref = nil then
    FValue.Ref := CreateJsArray;
  FArray^.Add(TJsonNode.CreateNull);
  Result := Self;
end;

function TJsonNode.Add(aValue: Boolean): TJsonNode;
begin
  if AsArray.FValue.Ref = nil then
    FValue.Ref := CreateJsArray;
  FArray^.Add(TJsonNode.Create(aValue));
  Result := Self;
end;

function TJsonNode.Add(aValue: Double): TJsonNode;
begin
  if AsArray.FValue.Ref = nil then
    FValue.Ref := CreateJsArray;
  FArray^.Add(TJsonNode.Create(aValue));
  Result := Self;
end;

function TJsonNode.Add(const aValue: string): TJsonNode;
begin
  if AsArray.FValue.Ref = nil then
    FValue.Ref := CreateJsArray;
  FArray^.Add(TJsonNode.Create(aValue));
  Result := Self;
end;

function TJsonNode.Add(const a: TJVarArray): TJsonNode;
begin
  if AsArray.FValue.Ref = nil then
    FValue.Ref := CreateJsArray;
  FArray^.Add(TJsonNode.Create(a));
  Result := Self;
end;

function TJsonNode.Add(const a: TJPairArray): TJsonNode;
begin
  if AsArray.FValue.Ref = nil then
    FValue.Ref := CreateJsArray;
  FArray^.Add(TJsonNode.Create(a));
  Result := Self;
end;

function TJsonNode.AddNode(aKind: TJsValueKind): TJsonNode;
begin
  if AsArray.FValue.Ref = nil then
    FValue.Ref := CreateJsArray;
  Result := TJsonNode.Create(aKind);
  FArray^.Add(Result);
end;

function TJsonNode.AddJson(const s: string; out aNode: TJsonNode): Boolean;
begin
  if AsArray.FValue.Ref = nil then
    FValue.Ref := CreateJsArray;
  Result := TryParse(s, aNode);
  if Result then
    FArray^.Add(aNode);
end;

function TJsonNode.Append(aNode: TJsonNode): TJsonNode;
var
  I: SizeInt;
  Node: TJsonNode;
begin
  if AsArray.FValue.Ref = nil then
    FValue.Ref := CreateJsArray;
  case aNode.Kind of
    jvkNull:   AddNull;
    jvkFalse,
    jvkTrue:   Add(aNode.AsBoolean);
    jvkNumber: Add(aNode.FValue.Num);
    jvkString: Add(aNode.FString);
    jvkArray:
      if aNode.Count <> 0 then
        begin
          for I := 0 to Pred(aNode.Count) do
            FArray^.Add(aNode.FArray^.UncMutable[I]^);
          aNode.FArray^.Clear;
        end;
    jvkObject:
      if aNode.Count <> 0 then
        begin
          for I := 0 to Pred(aNode.Count) do
            begin
              Node := TJsonNode.Create(jvkObject);
              Node.FValue.Ref := CreateJsObject;
              Node.FObject^.Add(aNode.FObject^.Mutable[I]^);
              FArray^.Add(Node);
            end;
          aNode.FObject^.Clear;
        end;
  else
    //todo: what about undefined ???
  end;
  Result := Self;
end;

function TJsonNode.AddNull(const aName: string): TJsonNode;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  FObject^.Add(TPair.Create(aName, TJsonNode.CreateNull));
  Result := Self;
end;

function TJsonNode.Add(const aName: string; aValue: Boolean): TJsonNode;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  FObject^.Add(TPair.Create(aName, TJsonNode.Create(aValue)));
  Result := Self;
end;

function TJsonNode.Add(const aName: string; aValue: Double): TJsonNode;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  FObject^.Add(TPair.Create(aName, TJsonNode.Create(aValue)));
  Result := Self;
end;

function TJsonNode.Add(const aName, aValue: string): TJsonNode;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  FObject^.Add(TPair.Create(aName, TJsonNode.Create(aValue)));
  Result := Self;
end;

function TJsonNode.Add(const aName: string; const aValue: TJVarArray): TJsonNode;
begin
   if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  FObject^.Add(TPair.Create(aName, TJsonNode.Create(aValue)));
  Result := Self;
end;

function TJsonNode.Add(const aName: string; const aValue: TJPairArray): TJsonNode;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  FObject^.Add(TPair.Create(aName, TJsonNode.Create(aValue)));
  Result := Self;
end;

function TJsonNode.AddNode(const aName: string; aKind: TJsValueKind): TJsonNode;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  Result := TJsonNode.Create(aKind);
  FObject^.Add(TPair.Create(aName, Result));
end;

function TJsonNode.AddJson(const aName, aJson: string; out aNode: TJsonNode): Boolean;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  Result := TryParse(aJson, aNode);
  if Result then
    FObject^.Add(TPair.Create(aName, aNode));
end;

function TJsonNode.AddUniqNull(const aName: string): Boolean;
var
  p: ^TPair;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  if FObject^.AddUniq(TPair.Create(aName, nil), p) then
    begin
      p^.Value := TJsonNode.CreateNull;
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.AddUniq(const aName: string; aValue: Boolean): Boolean;
var
  p: ^TPair;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  if FObject^.AddUniq(TPair.Create(aName, nil), p) then
    begin
      p^.Value := TJsonNode.Create(aValue);
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.AddUniq(const aName: string; aValue: Double): Boolean;
var
  p: ^TPair;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  if FObject^.AddUniq(TPair.Create(aName, nil), p) then
    begin
      p^.Value := TJsonNode.Create(aValue);
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.AddUniq(const aName, aValue: string): Boolean;
var
  p: ^TPair;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  if FObject^.AddUniq(TPair.Create(aName, nil), p) then
    begin
      p^.Value := TJsonNode.Create(aValue);
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.AddUniq(const aName: string; const aValue: TJVarArray): Boolean;
var
  p: ^TPair;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  if FObject^.AddUniq(TPair.Create(aName, nil), p) then
    begin
      p^.Value := TJsonNode.Create(aValue);
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.AddUniq(const aName: string; const aValue: TJPairArray): Boolean;
var
  p: ^TPair;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  if FObject^.AddUniq(TPair.Create(aName, nil), p) then
    begin
      p^.Value := TJsonNode.Create(aValue);
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.AddUniqNode(const aName: string; out aNode: TJsonNode; aKind: TJsValueKind): Boolean;
var
  p: ^TPair;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  if FObject^.AddUniq(TPair.Create(aName, nil), p) then
    begin
      aNode := TJsonNode.Create(aKind);
      p^.Value := aNode;
      exit(True);
    end;
  aNode := nil;
  Result := False;
end;

function TJsonNode.AddUniqJson(const aName, aJson: string; out aNode: TJsonNode): Boolean;
var
  p: ^TPair;
begin
  if TryParse(aJson, aNode) then
    begin
      if AsObject.FValue.Ref = nil then
        FValue.Ref := CreateJsObject;
      if FObject^.AddUniq(TPair.Create(aName, nil), p) then
        begin
          p^.Value := aNode;
          exit(True);
        end
      else
        FreeAndNil(aNode);
    end;
  Result := False;
end;

function TJsonNode.InsertNull(aIndex: SizeInt): Boolean;
begin
  if CanArrayInsert(aIndex) then
    begin
      FArray^.Insert(aIndex, TJsonNode.CreateNull);
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.Insert(aIndex: SizeInt; aValue: Boolean): Boolean;
begin
  if CanArrayInsert(aIndex) then
    begin
      FArray^.Insert(aIndex, TJsonNode.Create(aValue));
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.Insert(aIndex: SizeInt; aValue: Double): Boolean;
begin
  if CanArrayInsert(aIndex) then
    begin
      FArray^.Insert(aIndex, TJsonNode.Create(aValue));
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.Insert(aIndex: SizeInt; const aValue: string): Boolean;
begin
  if CanArrayInsert(aIndex) then
    begin
      FArray^.Insert(aIndex, TJsonNode.Create(aValue));
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.InsertNode(aIndex: SizeInt; out aNode: TJsonNode; aKind: TJsValueKind): Boolean;
begin
  if CanArrayInsert(aIndex) then
    begin
      aNode := TJsonNode.Create(aKind);
      FArray^.Insert(aIndex, aNode);
      exit(True);
    end;
  aNode := nil;
  Result := False;
end;

function TJsonNode.InsertNull(aIndex: SizeInt; const aName: string): Boolean;
begin
  if CanObjectInsert(aIndex) then
    begin
      FObject^.Insert(aIndex, TPair.Create(aName, TJsonNode.CreateNull));
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.Insert(aIndex: SizeInt; const aName: string; aValue: Boolean): Boolean;
begin
  if CanObjectInsert(aIndex) then
    begin
      FObject^.Insert(aIndex, TPair.Create(aName, TJsonNode.Create(aValue)));
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.Insert(aIndex: SizeInt; const aName: string; aValue: Double): Boolean;
begin
  if CanObjectInsert(aIndex) then
    begin
      FObject^.Insert(aIndex, TPair.Create(aName, TJsonNode.Create(aValue)));
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.Insert(aIndex: SizeInt; const aName, aValue: string): Boolean;
begin
  if CanObjectInsert(aIndex) then
    begin
      FObject^.Insert(aIndex, TPair.Create(aName, TJsonNode.Create(aValue)));
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.InsertNode(aIndex: SizeInt; const aName: string; out aNode: TJsonNode;
  aKind: TJsValueKind): Boolean;
begin
  if CanObjectInsert(aIndex) then
    begin
      aNode := TJsonNode.Create(aKind);
      FObject^.Insert(aIndex, TPair.Create(aName, aNode));
      exit(True);
    end;
  aNode := nil;
  Result := False;
end;

function TJsonNode.Contains(const aName: string): Boolean;
begin
  if (Kind = jvkObject) and (FValue.Ref <> nil) then
    exit(FObject^.Contains(aName));
  Result := False;
end;

function TJsonNode.ContainsUniq(const aName: string): Boolean;
begin
  if (Kind = jvkObject) and (FValue.Ref <> nil) then
    exit(FObject^.ContainsUniq(aName));
  Result := False;
end;

function TJsonNode.IndexOfName(const aName: string): SizeInt;
begin
  if (Kind = jvkObject) and (FValue.Ref <> nil) then
    exit(FObject^.IndexOf(aName));
  Result := NULL_INDEX;
end;

function TJsonNode.CountOfName(const aName: string): SizeInt;
begin
  if (Kind = jvkObject) and (FValue.Ref <> nil) then
    exit(FObject^.CountOf(aName));
  Result := 0;
end;

function TJsonNode.HasUniqName(aIndex: SizeInt): Boolean;
begin
  if (Kind = jvkObject) and (FValue.Ref <> nil) then
    exit(FObject^.HasUniqKey(aIndex));
  Result := False;
end;

function TJsonNode.Find(const aKey: string; out aValue: TJsonNode): Boolean;
var
  p: ^TPair;
begin
  if (Kind = jvkObject) and (FValue.Ref <> nil) then
    begin
      p := FObject^.Find(aKey);
      if p <> nil then
        begin
          aValue := p^.Value;
          exit(True);
        end;
    end;
  aValue := nil;
  Result := False;
end;

function TJsonNode.FindOrAdd(const aName: string; out aValue: TJsonNode): Boolean;
var
  p: ^TPair;
begin
  if AsObject.FValue.Ref = nil then
    FValue.Ref := CreateJsObject;
  Result := FObject^.FindOrAdd(aName, p);
  if not Result then
    begin
      p^.Key := aName;
      p^.Value := TJsonNode.Create;
    end;
  aValue := p^.Value;
end;

function TJsonNode.FindUniq(const aName: string; out aValue: TJsonNode): Boolean;
var
  p: ^TPair;
begin
  if (Kind = jvkObject) and (FValue.Ref <> nil) then
    begin
      p := FObject^.FindUniq(aName);
      if p <> nil then
        begin
          aValue := p^.Value;
          exit(True);
        end;
    end;
  aValue := nil;
  Result := False;
end;

function TJsonNode.FindAll(const aName: string): TNodeArray;
var
  r: TNodeArray = nil;
  I: SizeInt;
  e: TPair;
begin
  if (Kind = jvkObject) and (FValue.Ref <> nil) then
    begin
      System.SetLength(r, ARRAY_INITIAL_SIZE);
      I := 0;
      for e in FObject^.EqualKeys(aName) do
        begin
          if I = System.Length(r) then
            System.SetLength(r, I * 2);
          r[I] := e.Value;
          Inc(I);
        end;
      System.SetLength(r, I);
      exit(r);
    end;
  Result := nil;
end;

function TJsonNode.Find(aIndex: SizeInt; out aValue: TJsonNode): Boolean;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    begin
      case Kind of
        jvkArray:  aValue := FArray^.UncMutable[aIndex]^;
        jvkObject: aValue := FObject^.Mutable[aIndex]^.Value;
      else
      end;
      exit(True);
    end;
  aValue := nil;
  Result := False;
end;

function TJsonNode.FindPair(aIndex: SizeInt; out aValue: TPair): Boolean;
begin
  if (Kind=jvkObject)and(FObject<>nil)and(SizeUInt(aIndex)<SizeUInt(FObject^.Count))then
     begin
       aValue := FObject^.Mutable[aIndex]^;
       exit(True);
     end;
  aValue := Default(TPair);
  Result := False;
end;

function TJsonNode.FindName(aIndex: SizeInt; out aName: string): Boolean;
begin
  if (Kind=jvkObject)and(FObject<>nil)and(SizeUInt(aIndex)<SizeUInt(FObject^.Count))then
     begin
       aName := FObject^.Mutable[aIndex]^.Key;
       exit(True);
     end;
  aName := '';
  Result := False;
end;

function TJsonNode.Delete(aIndex: SizeInt): Boolean;
var
  Node: TJsonNode;
begin
  if Extract(aIndex, Node) then
    begin
      Node.Free;
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.Extract(aIndex: SizeInt; out aNode: TJsonNode): Boolean;
var
  p: TPair;
begin
  aNode := nil;
  case Kind of
    jvkArray: exit(FArray^.TryExtract(aIndex, aNode));
    jvkObject:
      if (FObject <> nil) and FObject^.TryDelete(aIndex, p) then
        begin
          aNode := p.Value;
          exit(True);
        end;
  else
  end;
  Result := False;
end;

function TJsonNode.Extract(aIndex: SizeInt; out aPair: TPair): Boolean;
begin
  if (Kind = jvkObject) and (FObject <> nil) and FObject^.TryDelete(aIndex, aPair) then
    exit(True);
  aPair := Default(TPair);
  Result := False;
end;

function TJsonNode.Extract(const aName: string; out aNode: TJsonNode): Boolean;
var
  p: TPair;
begin
  if (Kind = jvkObject) and (FObject <> nil) and FObject^.Remove(aName, p) then
    begin
      aNode := p.Value;
      exit(True);
    end;
  aNode := nil;
  Result := False;
end;

function TJsonNode.Remove(const aName: string): Boolean;
var
  Node: TJsonNode;
begin
  if Extract(aName, Node) then
    begin
      Node.Free;
      exit(True);
    end;
  Result := False;
end;

function TJsonNode.RemoveAll(const aName: string): SizeInt;
var
  p: TPair;
begin
  p := Default(TPair);
  if (Kind = jvkObject) and (FObject <> nil) then
    begin
      Result := FObject^.Count;
      while FObject^.Remove(aName, p) do
        p.Value.Free;
      Result := Result - FObject^.Count;
    end;
  Result := 0;
end;

{$PUSH}{$Q-}{$R-}
function Str2IntOrNull(const s: string): SizeInt;
const
  Digits: array['0'..'9'] of SizeUInt = (0,1,2,3,4,5,6,7,8,9);
  TestVal: SizeUInt =
{$IF DEFINED(CPU64)}
  SizeUInt(10000000000000000000);
{$ELSEIF DEFINED(CPU32)}
  SizeUInt(1000000000);
{$ELSEIF DEFINED(CPU16)}
  SizeUInt(10000);
{$ELSE}
  {$FATAL Not supported}
{$ENDIF}
  MaxLen: Integer =
{$IF DEFINED(CPU64)}
  20;
{$ELSEIF DEFINED(CPU32)}
  10;
{$ELSEIF DEFINED(CPU16)}
  5;
{$ELSE}
  {$FATAL Not supported}
{$ENDIF}
var
  I: Integer;
  r: SizeUInt;
  c: AnsiChar;
begin
  if (s = '') or (System.Length(s) > MaxLen) then
    exit(NULL_INDEX);
  c := s[1];
  //leading zeros or spaces are not allowed
  if not(c in ['1'..'9']) then
    exit(NULL_INDEX);
  r := Digits[c];
  for I := 2 to System.Length(s) do
    begin
      c := s[I];
      if not(c in ['0'..'9']) then
        exit(NULL_INDEX);
      r := r * 10 + Digits[c];
    end;
  if (System.Length(s) = MaxLen) and (r < TestVal) then
    exit(NULL_INDEX);
  if r > System.High(SizeInt) then
    exit(NULL_INDEX);
  Result := SizeInt(r);
end;
{$POP}

function IsNonNegativeInt(const s: string; out aInt: SizeInt): Boolean;
const
  Digits: array['0'..'9'] of SizeInt = (0,1,2,3,4,5,6,7,8,9);
begin
  if s = '' then exit(False);
  if System.Length(s) = 1 then
    begin
      if s[1] in ['0'..'9'] then
        begin
          aInt := Digits[s[1]];
          exit(True)
        end;
      exit(False);
    end;
  aInt := Str2IntOrNull(s);
  Result := aInt <> NULL_INDEX;
end;

function TJsonNode.FindPath(const aPath: array of string; out aNode: TJsonNode): Boolean;
var
  Node: TJsonNode;
  I, Idx: SizeInt;
begin
  if System.Length(aPath) = 0 then
    begin
      aNode := Self;
      exit(True);
    end;
  Node := Self;
  aNode := nil;
  for I := 0 to System.High(aPath) do
    if Node.IsArray then
      begin
        if aPath[I] = '-' then
          begin
            if I <> System.High(aPath) then
              exit(False);
            aNode := Node.AddNode(jvkNull);
            exit(True);
          end
        else
          if not IsNonNegativeInt(aPath[I], Idx) then
            exit(False);
        if not Node.Find(Idx, Node) then
          exit(False);
      end
    else
      if not Node.FindUniq(aPath[I], Node) then
        exit(False);
  aNode := Node;
  Result := Node <> nil;
end;

function TJsonNode.FindPath(const aPath: array of string): TJsonNode;
begin
  FindPath(aPath, Result);
end;

function TJsonNode.FindPath(const aPtr: TJsonPtr; out aNode: TJsonNode): Boolean;
begin
  if aPtr.IsEmpty then
    begin
      aNode := Self;
      exit(True);
    end;
  Result := FindPath(aPtr.ToSegments, aNode);
end;

function TJsonNode.FindPath(const aPtr: TJsonPtr): TJsonNode;
begin
  FindPath(aPtr, Result);
end;

function TJsonNode.FindPathPtr(const aPtr: string; out aNode: TJsonNode): Boolean;
var
  Segments: TStringArray = nil;
begin
  if aPtr = '' then
    begin
      aNode := Self;
      exit(True);
    end;
  if not TJsonPtr.TryGetSegments(aPtr, Segments) then
    begin
      aNode := nil;
      exit(False);
    end;
  Result := FindPath(Segments, aNode);
end;

function TJsonNode.FindPathPtr(const aPtr: string): TJsonNode;
begin
  FindPathPtr(aPtr, Result);
end;

function TJsonNode.FormatJson(aOptions: TJsFormatOptions; aIndentSize: Integer; aOffset: Integer): string;
var
  sb: TStrBuilder;
  Pair: TPair;
  s: shortstring;
  MultiLine, UseTabs, StrEncode, BsdBrace, HasText, OneLineArray, OneLineObject: Boolean;
  Node: TJsonNode;
  procedure NewLine(Pos: Integer); inline;
  begin
    sb.Append(sLineBreak);
    if UseTabs then
      sb.Append(#9, Pos)
    else
      sb.Append(chSpace, Pos);
  end;
  procedure AppendString(const s: string); inline;
  begin
    if StrEncode then
      sb.AppendEncode(s)
    else
      begin
        sb.Append(chQuote);
        sb.Append(s);
        sb.Append(chQuote);
      end;
  end;
  procedure CheckHasText(Pos: Integer; aRoot: Boolean); inline;
  begin
    if HasText then
      if (MultiLine or aRoot) and BsdBrace then
        NewLine(Pos) else
    else
      HasText := True;
  end;
  procedure BuildJson(aInst: TJsonNode; aPos: Integer);
  var
    I, Last: SizeInt;
    IsRoot, OldMultiLine: Boolean;
  begin
    IsRoot := False;
    OldMultiLine := MultiLine;
    case aInst.Kind of
      jvkNull:   sb.Append(JS_NULL);
      jvkFalse:  sb.Append(JS_FALSE);
      jvkTrue:   sb.Append(JS_TRUE);
      jvkNumber:
        begin
          Double2Str(aInst.FValue.Num, s);
          sb.Append(s);
        end;
      jvkString: AppendString(aInst.FString);
      jvkArray:
        begin
          if OneLineArray or OneLineObject then
            if HasText then
              if OneLineArray then
                MultiLine := False else
            else
              if OneLineArray or OneLineObject then
                IsRoot := True;
          CheckHasText(aPos, IsRoot);
          sb.Append(chOpenSqrBr);
          if aInst.FArray <> nil then begin
            Last := Pred(aInst.FArray^.Count);
            for I := 0 to Last do begin
              Node := aInst.FArray^.UncMutable[I]^;
              if (Node.IsScalar and MultiLine) or IsRoot then
                NewLine(aPos + aIndentSize)
              else
                if (I = 0) and (Node.IsStruct and not BsdBrace and MultiLine)then
                  NewLine(aPos + aIndentSize);
              BuildJson(aInst.FArray^.UncMutable[I]^, aPos + aIndentSize);
              if I <> Last then begin
                sb.Append(chComma);
                if not MultiLine or (aInst.FArray^.UncMutable[I+1]^.IsStruct and not BsdBrace) then
                  sb.Append(chSpace);
              end;
            end;
          end;
          if MultiLine or IsRoot then NewLine(aPos);
          sb.Append(chClosSqrBr);
          if OneLineArray and not IsRoot then
            MultiLine := OldMultiLine;
        end;
      jvkObject:
        begin
            if HasText then
              if OneLineObject then
                MultiLine := False else
            else
              if OneLineArray or OneLineObject then
                IsRoot := True;
          CheckHasText(aPos, IsRoot);
          sb.Append(chOpenCurBr);
          if aInst.FObject <> nil then begin
            Last := Pred(aInst.FObject^.Count);
            for I := 0 to Last do begin
              if MultiLine or IsRoot then NewLine(aPos + aIndentSize);
              Pair := aInst.FObject^.Mutable[I]^;
              Node := Pair.Value;
              AppendString(Pair.Key);
              sb.Append(chColon);
              if Node.IsScalar or not MultiLine or (OneLineArray and Node.IsArray) or
                (OneLineObject and Node.IsObject) then begin
                sb.Append(chSpace);
                BuildJson(Pair.Value, aPos);
              end else begin
                if not BsdBrace then sb.Append(chSpace);
                BuildJson(Pair.Value, aPos + aIndentSize);
              end;
              if I <> Last then begin
                sb.Append(chComma);
                if not MultiLine then sb.Append(chSpace);
              end;
            end;
          end;
          if MultiLine or IsRoot then NewLine(aPos);
          sb.Append(chClosCurBr);
          if OneLineObject and not IsRoot then
            MultiLine := OldMultiLine;
        end;
    else
    end;
  end;
begin //todo: make it somehow easier?
  sb := TStrBuilder.Create(S_BUILD_INIT_SIZE);
  MultiLine := not(jfoSingleLine in aOptions);
  OneLineArray := (jfoSingleLineArray in aOptions) and MultiLine;
  OneLineObject := (jfoSingleLineObject in aOptions) and MultiLine;
  UseTabs := jfoUseTabs in aOptions;
  StrEncode := not(jfoStrAsIs in aOptions);
  BsdBrace := not(jfoEgyptBrace in aOptions);
  HasText := False;
  aOffset := Math.Max(aOffset, 0);
  if UseTabs then
    sb.Append(#9, aOffset)
  else
    sb.Append(chSpace, aOffset);
  BuildJson(Self, aOffset);
  Result := sb.ToString;
end;

function TJsonNode.GetValue(out aValue: TJVariant): Boolean;
begin
  if not IsScalar then exit(False);
  case Kind of
    jvkNull:   aValue.SetNull;
    jvkFalse:  aValue := False;
    jvkTrue:   aValue := True;
    jvkNumber: aValue := FValue.Num;
    jvkString: aValue := string(FValue.Ref);
  else
  end;
  Result := True;
end;

function TJsonNode.SaveToStream(aStream: TStream): SizeInt;
begin
  Result := DoBuildJson.SaveToStream(aStream);
end;

procedure TJsonNode.SaveToFile(const aFileName: string);
var
  fs: TFileStream = nil;
begin
  fs := TFileStream.Create(aFileName, fmOpenWrite or fmCreate);
  try
    //SaveToStream(fs);
    TJsonWriter.WriteJson(fs, Self);
  finally
    fs.Free;
  end;
end;

function TJsonNode.ToString: string;
begin
  case Kind of
    jvkUnknown: Result := JS_UNDEF;
    jvkNull:    Result := JS_NULL;
    jvkFalse:   Result := JS_FALSE;
    jvkTrue:    Result := JS_TRUE;
    jvkNumber:  Result := Double2StrDef(FValue.Num);
    jvkString:  Result := FString;
    jvkArray,
    jvkObject:  Result := FormatJson([jfoSingleLine, jfoStrAsIs]);
  end;
end;

{ TJsonPatch }

class function TJsonPatch.FindOp(aNode: TJsonNode; var aOpNode: TJsonNode): Boolean;
begin
  if not aNode.IsObject or (aNode.Count = 0) then
    exit(False);
  if not(aNode.FindUniq(OP_KEY, aOpNode) and aOpNode.IsString) then
    exit(False);
  Result := True;
end;

class function TJsonPatch.TestPathValue(aNode: TJsonNode): Boolean;
var
  Node: TJsonNode;
begin
  if not(aNode.FindUniq(PATH_KEY, Node) and Node.IsString) then
    exit(False);
  if not TJsonPtr.ValidPtr(Node.AsString) then
    exit(False);
  if not aNode.FindUniq(VAL_KEY, Node) or (Node.Kind = jvkUnknown) then
    exit(False);
  Result := True;
end;

class function TJsonPatch.TestPath(aNode: TJsonNode): Boolean;
var
  Node: TJsonNode;
begin
  if not(aNode.FindUniq(PATH_KEY, Node) and Node.IsString) then
    exit(False);
  if not TJsonPtr.ValidPtr(Node.AsString) then
    exit(False);
  Result := True;
end;

class function TJsonPatch.TestMovePaths(aNode: TJsonNode): Boolean;
var
  Node: TJsonNode;
  PathFrom, PathTo: TStringArray;
begin
  if not(aNode.FindUniq(FROM_KEY, Node) and Node.IsString) then
    exit(False);
  if not TJsonPtr.TryGetSegments(Node.AsString, PathFrom) then
    exit(False);
  if not(aNode.FindUniq(PATH_KEY, Node) and Node.IsString) then
    exit(False);
  if not TJsonPtr.TryGetSegments(Node.AsString, PathTo) then
    exit(False);
  if TStrUtil.IsPrefix(PathFrom, PathTo) then
    exit(False);
  Result := True;
end;

class function TJsonPatch.TestCopyPaths(aNode: TJsonNode): Boolean;
var
  Node: TJsonNode;
begin
  if not(aNode.FindUniq(FROM_KEY, Node) and Node.IsString) then
    exit(False);
  if not TJsonPtr.ValidPtr(Node.AsString) then
    exit(False);
  if not(aNode.FindUniq(PATH_KEY, Node) and Node.IsString) then
    exit(False);
  if not TJsonPtr.ValidPtr(Node.AsString) then
    exit(False);
  Result := True;
end;

class function TJsonPatch.GetValAndPath(aNode: TJsonNode; var aValNode: TJsonNode;
  out aPath: TStringArray): Boolean;
begin
  if not(aNode.FindUniq(PATH_KEY, aValNode) and aValNode.IsString) then
    exit(False);
  if not TJsonPtr.TryGetSegments(aValNode.AsString, aPath) then
    exit(False);
  if not aNode.FindUniq(VAL_KEY, aValNode) or (aValNode.Kind = jvkUnknown) then
    exit(False);
  Result := True;
end;

class function TJsonPatch.GetMovePaths(aNode: TJsonNode; var aPathNode: TJsonNode;
  out aFrom, aTo: TStringArray): Boolean;
begin
  if not(aNode.FindUniq(FROM_KEY, aPathNode) and aPathNode.IsString) then
    exit(False);
  if not TJsonPtr.TryGetSegments(aPathNode.AsString, aFrom) then
    exit(False);
  if not(aNode.FindUniq(PATH_KEY, aPathNode) and aPathNode.IsString) then
    exit(False);
  if not TJsonPtr.TryGetSegments(aPathNode.AsString, aTo) then
    exit(False);
  if (System.Length(aFrom) < System.Length(aTo)) and TStrUtil.IsPrefix(aFrom, aTo) then
    exit(False);
  Result := True;
end;

class function TJsonPatch.GetCopyPaths(aNode: TJsonNode; var aPathNode: TJsonNode;
  out aFrom, aTo: TStringArray): Boolean;
begin
  if not(aNode.FindUniq(FROM_KEY, aPathNode) and aPathNode.IsString) then
    exit(False);
  if not TJsonPtr.TryGetSegments(aPathNode.AsString, aFrom) then
    exit(False);
  if not(aNode.FindUniq(PATH_KEY, aPathNode) and aPathNode.IsString) then
    exit(False);
  if not TJsonPtr.TryGetSegments(aPathNode.AsString, aTo) then
    exit(False);
  Result := True;
end;

class function TJsonPatch.GetPath(aNode: TJsonNode; var aPathNode: TJsonNode;
  out aPath: TStringArray): Boolean;
begin
  if not(aNode.FindUniq(PATH_KEY, aPathNode) and aPathNode.IsString) then
    exit(False);
  if not TJsonPtr.TryGetSegments(aPathNode.AsString, aPath) then
    exit(False);
  Result := True;
end;

class function TJsonPatch.FindExistStruct(aNode: TJsonNode; const aPath: TStringArray; out aStruct: TJsonNode;
  out aStructKey: string): Boolean;
begin
  if aPath = nil then
    exit(False);
  if not aNode.FindPath(aPath[0..Pred(System.High(aPath))], aStruct) then
    exit(False);
  if not aStruct.IsStruct then
    exit(False);
  aStructKey := aPath[System.High(aPath)];
  Result := True;
end;

class procedure TJsonPatch.MoveNode(aSrc, aDst: TJsonNode);
begin
  aDst.Clear;
  aDst.FValue := aSrc.FValue;
  aDst.FKind := aSrc.FKind;
  aSrc.FKind := jvkUnknown;
  aSrc.FValue.Int := 0;
end;

class function TJsonPatch.FindCopyValue(aNode: TJsonNode; const aPath: TStringArray; out aValue: TJsonNode): Boolean;
var
  Node: TJsonNode;
  Idx: SizeInt;
  Key: string;
begin
  if aPath = nil then
    exit(False);
  if not FindExistStruct(aNode, aPath, Node, Key) then
    exit(False);
  if Node.IsArray then
    begin
      if not IsNonNegativeInt(Key, Idx) then
        exit(False);
      Result := Node.Find(Idx, aValue);
    end
  else
    Result := Node.FindUniq(Key, aValue);
end;

{$PUSH}{$WARN 5036 OFF}
class function TJsonPatch.TryAdd(aNode, aValue: TJsonNode; const aPath: TStringArray): Boolean;
var
  Node: TJsonNode;
  Idx: SizeInt;
  Key: string;
begin
  if aPath = nil then
    begin
      aNode.CopyFrom(aValue);
      exit(True);
    end;
  if not FindExistStruct(aNode, aPath, Node, Key) then
    exit(False);
  if Node.IsArray then
    begin
      if Key = '-' then
        begin
          Node.AddNode(aValue.Kind).CopyFrom(aValue);
          exit(True);
        end;
      if not IsNonNegativeInt(Key, Idx) then
        exit(False);
      Result := Node.InsertNode(Idx, Node, aValue.Kind);
      if Result then
        Node.CopyFrom(aValue);
    end
  else
    begin
      Idx := Node.IndexOfName(Key);
      if Idx = NULL_INDEX then
        Node.AddNode(Key).CopyFrom(aValue)
      else
        begin
          if not Node.FObject^.HasUniqKey(Idx) then
            exit(False);
          Node.FObject^.Mutable[Idx]^.Value.CopyFrom(aValue);
        end;
      Result := True;
    end;
end;
{$POP}

class function TJsonPatch.TryRemove(aNode: TJsonNode; const aPath: TStringArray): Boolean;
var
  Node: TJsonNode;
  Idx: SizeInt;
  Key: string;
begin
  if not FindExistStruct(aNode, aPath, Node, Key) then
    exit(False);
  if Node.IsArray then
    begin
      if not IsNonNegativeInt(Key, Idx) then
        exit(False);
      Result := Node.Delete(Idx);
    end
  else
    begin
      if not Node.ContainsUniq(Key) then
        exit(False);
      Result := Node.Remove(Key);
    end;
end;

class function TJsonPatch.TryExtract(aNode: TJsonNode; const aPath: TStringArray;
  out aValue: TJsonNode): Boolean;
var
  Node: TJsonNode;
  Idx: SizeInt;
  Key: string;
begin
  if not FindExistStruct(aNode, aPath, Node, Key) then
    exit(False);
  if Node.IsArray then
    begin
      if not IsNonNegativeInt(Key, Idx) then
        exit(False);
      Result := Node.Extract(Idx, aValue);
    end
  else
    begin
      if not Node.ContainsUniq(Key) then
        exit(False);
      Result := Node.Extract(Key, aValue);
    end;
end;

class function TJsonPatch.TryMove(aNode, aValue: TJsonNode; const aPath: TStringArray): Boolean;
var
  Node: TJsonNode;
  Idx: SizeInt;
  Key: string;
begin
  if not FindExistStruct(aNode, aPath, Node, Key) then
    exit(False);
  if Node.IsArray then
    begin
      if Key = '-' then
        begin
          if Node.FArray = nil then
            Node.FArray := Node.CreateJsArray;
          Node.FArray^.Insert(Node.Count, aValue);
          exit(True);
        end;
      if not IsNonNegativeInt(Key, Idx) then
        exit(False);
      if not Node.CanArrayInsert(Idx) then
        exit(False);
      Node.FArray^.Insert(Idx, aValue);
    end
  else
    begin
      Idx := Node.IndexOfName(Key);
      if Idx = NULL_INDEX then
        begin
          if Node.FObject = nil then
            Node.FObject := Node.CreateJsObject;
          Node.FObject^.Add(TJsonNode.TPair.Create(Key, aValue));
        end
      else
        begin
          if not Node.FObject^.HasUniqKey(Idx) then
            exit(False);
          with Node.FObject^.Mutable[Idx]^ do
            begin
              Value.Free;
              Value := aValue;
            end;
        end;
    end;
  Result := True;
end;

class function TJsonPatch.TryReplace(aNode, aValue: TJsonNode; const aPath: TStringArray): Boolean;
var
  Node: TJsonNode;
  Idx: SizeInt;
  Key: string;
begin
  if aPath = nil then
    begin
      aNode.CopyFrom(aValue);
      exit(True);
    end;
  if not FindExistStruct(aNode, aPath, Node, Key) then
    exit(False);
  if Node.IsArray then
    begin
      if not IsNonNegativeInt(Key, Idx) then
        exit(False);
      Result := Node.Find(Idx, Node);
    end
  else
    Result := Node.FindUniq(Key, Node);
  if Result then
    Node.CopyFrom(aValue);
end;

class function TJsonPatch.TryTest(aNode, aValue: TJsonNode; const aPath: TStringArray): Boolean;
var
  Node: TJsonNode = nil;
begin
  if not aNode.FindPath(aPath, Node) then
    exit(False);
  Result := Node.EqualTo(aValue);
end;

function TJsonPatch.GetAsJson: string;
begin
  if Loaded then
    exit(FNode.AsJson);
  Result := '';
end;

function TJsonPatch.SeemsValidPatch(aNode: TJsonNode): Boolean;
var
  CurrNode, TmpNode: TJsonNode;
  I: SizeInt;
begin
  if (aNode = nil) or not aNode.IsArray then
    exit(False);
  for I := 0 to Pred(aNode.Count) do
    begin
      CurrNode := aNode.Items[I];
      if not FindOp(CurrNode, TmpNode) then
        exit(False);
      case TmpNode.AsString of
        ADD_KEY, REPLACE_KEY, TEST_KEY:
          if not TestPathValue(CurrNode) then
            exit(False);
        COPY_KEY:
          if not TestCopyPaths(CurrNode) then
            exit(False);
        MOVE_KEY:
          if not TestMovePaths(CurrNode) then
            exit(False);
        REMOVE_KEY:
          if not TestPath(CurrNode) then
            exit(False);
      else
        exit(False);
      end;
    end;
  Result := True;
end;

{$PUSH}{$WARN 5089 OFF}{$WARN 5036 OFF}
function TJsonPatch.ApplyValidated(aNode: TJsonNode): TPatchResult;
var
  CopyNode, CurrNode, TmpNode: TJsonNode;
  I: SizeInt;
  PathFrom, PathTo: TStringArray;
  CopyRef: specialize TGUniqRef<TJsonNode>;
begin
  CopyRef.Instance := aNode.Clone;
  CopyNode := CopyRef;
  for I := 0 to Pred(FNode.Count) do
    begin
      CurrNode := FNode.Items[I];
      FindOp(CurrNode, TmpNode);
      case TmpNode.AsString of
        ADD_KEY:
          begin
            GetValAndPath(CurrNode, TmpNode, PathFrom);
            if not TryAdd(CopyNode, TmpNode, PathFrom) then
              exit(prFail);
          end;
        COPY_KEY:
          begin
            GetCopyPaths(CurrNode, TmpNode, PathFrom, PathTo);
            if not FindCopyValue(CopyNode, PathFrom, TmpNode) then
              exit(prFail);
            if not TryAdd(CopyNode, TmpNode, PathTo) then
              exit(prFail);
          end;
        MOVE_KEY:
          begin
            GetMovePaths(CurrNode, TmpNode, PathFrom, PathTo);
            if not TryExtract(CopyNode, PathFrom, TmpNode) then
              exit(prFail);
            if not TryMove(CopyNode, TmpNode, PathTo) then
              begin
                TmpNode.Free;
                exit(prFail);
              end;
          end;
        REMOVE_KEY:
          begin
            if not GetPath(CurrNode, TmpNode, PathFrom) then
              exit(prMalformPatch);
            if not TryRemove(CopyNode, PathFrom) then
              exit(prFail);
          end;
        REPLACE_KEY:
          begin
            if not GetValAndPath(CurrNode, TmpNode, PathFrom) then
              exit(prMalformPatch);
            if not TryReplace(CopyNode, TmpNode, PathFrom) then
              exit(prFail);
          end;
        TEST_KEY:
          begin
            if not GetValAndPath(CurrNode, TmpNode, PathFrom) then
              exit(prMalformPatch);
            if not TryTest(CopyNode, TmpNode, PathFrom) then
              exit(prFail);
          end;
      else
        exit(prMalformPatch);
      end;
    end;
  MoveNode(CopyNode, aNode);
  Result := prOk;
end;
{$POP}

class function TJsonPatch.Diff(aSource, aTarget: TJsonNode; out aDiff: TJsonNode;
  aOptions: TDiffOptions): TDiffResult;
var
  Path: TStrVector;
  TestRemove, TestReplace, UseArrayReplace: Boolean;

  function GetCurrPath: string; inline;
  begin
    Result := TJsonPtr.ToPointer(Path.UncMutable[0][0..Pred(Path.Count)]);
  end;

  procedure PushTest(const aPath: string; aValue: TJsonNode); inline;
  begin
    aDiff.AddNode(jvkObject)
      .Add(OP_KEY, TEST_KEY)
      .Add(PATH_KEY, aPath)
      .AddNode(VAL_KEY).CopyFrom(aValue);
  end;

  procedure PushReplace(const aKey: string; aOldValue, aNewValue: TJsonNode);
  var
    CurrPath: string;
  begin
    Path.Add(aKey);
    CurrPath := GetCurrPath;
    if TestReplace then
      PushTest(CurrPath, aOldValue);
    aDiff.AddNode(jvkObject)
      .Add(OP_KEY, REPLACE_KEY)
      .Add(PATH_KEY, CurrPath)
      .AddNode(VAL_KEY).CopyFrom(aNewValue);
    Path.DeleteLast;
  end;

  procedure PushReplace(aOldValue, aNewValue: TJsonNode);
  var
    CurrPath: string;
  begin
    CurrPath := GetCurrPath;
    if TestReplace then
      PushTest(CurrPath, aOldValue);
    aDiff.AddNode(jvkObject)
      .Add(OP_KEY, REPLACE_KEY)
      .Add(PATH_KEY, CurrPath)
      .AddNode(VAL_KEY).CopyFrom(aNewValue);
  end;

  procedure PushAdd(const aKey: string; aValue: TJsonNode); inline;
  begin
    Path.Add(aKey);
    aDiff.AddNode(jvkObject)
      .Add(OP_KEY, ADD_KEY)
      .Add(PATH_KEY, GetCurrPath)
      .AddNode(VAL_KEY).CopyFrom(aValue);
    Path.DeleteLast;
  end;

  procedure PushRemove(const aKey: string; aValue: TJsonNode);
  var
    CurrPath: string;
  begin
    Path.Add(aKey);
    CurrPath := GetCurrPath;
    if TestRemove then
      PushTest(CurrPath, aValue);
    aDiff.AddNode(jvkObject)
      .Add(OP_KEY, REMOVE_KEY)
      .Add(PATH_KEY, CurrPath);
    Path.DeleteLast;
  end;

  function DoDiff(aSrc, aDst: TJsonNode): Boolean; forward;

  function DoArrayDiff(aSrc, aDst: TJsonNode): Boolean;
  var
    LocDiff: TDiffUtil.TDiff;
    I, DelIdx, InsIdx, DelLen, InsLen: SizeInt;
    Del, Ins: array of Boolean;
  begin
    if aSrc.Count = 0 then begin
      for I := 0 to Pred(aDst.Count) do
        PushAdd(SizeUInt2Str(I), aDst.Items[I]);
      exit(True);
    end else
      if aDst.Count = 0 then begin
        for I := 0 to Pred(aSrc.Count) do
          PushRemove(SizeUInt2Str(I), aSrc.Items[I]);
        exit(True);
      end;

    LocDiff := TDiffUtil.Diff(aSrc.FArray^.UncMutable[0][0..Pred(aSrc.Count)],
                              aDst.FArray^.UncMutable[0][0..Pred(aDst.Count)]);
    Del := LocDiff.SourceChanges;
    Ins := LocDiff.TargetChanges;
    DelLen := System.Length(Del);
    InsLen := System.Length(Ins);
    if UseArrayReplace then
      begin
        DelIdx := 0;
        InsIdx := 0;
        repeat
          while(DelIdx < DelLen)and Del[DelIdx]and(InsIdx < InsLen)and Ins[InsIdx]do begin
            Path.Add(SizeUInt2Str(DelIdx)); //replacements
            /////////////
            if not DoDiff(aSrc.Items[DelIdx], aDst.Items[InsIdx]) then
              exit(False);
            /////////////
            Path.DeleteLast;
            Del[DelIdx] := False;
            Inc(DelIdx);
            Ins[InsIdx] := False;
            Inc(InsIdx);
          end;
          while (DelIdx < DelLen) and Del[DelIdx] do
            Inc(DelIdx);
          while (InsIdx < InsLen) and Ins[InsIdx] do
            Inc(InsIdx);
          Inc(DelIdx);
          Inc(InsIdx);
        until (DelIdx >= DelLen) and (InsIdx >= InsLen);
      end;

    for DelIdx := Pred(DelLen) downto 0 do
      if Del[DelIdx] then
        PushRemove(SizeUInt2Str(DelIdx), aSrc.Items[DelIdx]);

    for InsIdx := 0 to Pred(InsLen) do
      if Ins[InsIdx] then
        PushAdd(SizeUInt2Str(InsIdx), aDst.Items[InsIdx]);

    Result := True;
  end;

  function DoObjectDiff(aSrc, aDst: TJsonNode): Boolean;
  var
    p: TJsonNode.TPair;
    Node: TJsonNode;
    I: SizeInt;
  begin
    for I := 0 to Pred(aSrc.Count) do begin
      if not aSrc.FObject^.HasUniqKey(I) then
        exit(False);
      p := aSrc.FObject^.Mutable[I]^;
      if aDst.Find(p.Key, Node) then  //todo: IndexOfName() ???
        if aDst.ContainsUniq(p.Key) then begin
          Path.Add(p.Key);
          /////////////
          if not DoDiff(p.Value, Node) then
            exit(False);
          /////////////
          Path.DeleteLast;
        end else
          exit(False)
      else
        PushRemove(p.Key, p.Value);
    end;
    for I := 0 to Pred(aDst.Count) do begin
      p := aDst.FObject^.Mutable[I]^;
      if not aSrc.Contains(p.Key) then begin
        if not aDst.HasUniqName(I) then
          exit(False);
        PushAdd(p.Key, p.Value);
      end;
    end;
    Result := True;
  end;

  function DoDiff(aSrc, aDst: TJsonNode): Boolean;
  begin
    if aSrc.Kind <> aDst.Kind then begin
      PushReplace(aSrc, aDst);
      exit(True);
    end;

    case aSrc.Kind of
      jvkNull, jvkFalse, jvkTrue: Result := True;
      jvkNumber: begin
          if aSrc.AsNumber <> aDst.AsNumber then
            PushReplace(aSrc, aDst);
          Result := True;
        end;
      jvkString: begin
          if aSrc.AsString <> aDst.AsString then
            PushReplace(aSrc, aDst);
          Result := True;
        end;
      jvkArray: Result := DoArrayDiff(aSrc, aDst);
      jvkObject: Result := DoObjectDiff(aSrc, aDst);
    otherwise
      exit(False);
    end;
  end;

type
  TUseOp = (uoAdd, uoRemove, uoOther);

  function GetUseOp(aNode: TJsonNode): TUseOp;
  var
    Node: TJsonNode;
  begin
    aNode.Find(OP_KEY, Node);
    case Node.AsString of
      ADD_KEY:     Result := uoAdd;
      REMOVE_KEY:  Result := uoRemove;
    else
      Result := uoOther;
    end;
  end;

  function IsPrefixPath(const aFrom, aTo: string): Boolean; inline;
  begin
    if aFrom = aTo then exit(False);
    Result := TStrUtil.IsPrefix(TJsonPtr.ToSegments(aFrom), TJsonPtr.ToSegments(aTo));
  end;

  procedure TryRemoveAdd2Move(aSrc, aDst: TJsonNode);
  var
    Cmd, NextCmd, Value, Tmp: TJsonNode;
    RemovePath, AddPath: string;
    I, J: SizeInt;
  begin
    I := 0;
    while I < aDiff.Count do begin
      Cmd := aDiff.Items[I];
      case GetUseOp(Cmd) of
        uoAdd: begin
            Cmd.Find(VAL_KEY, Value);
            for J := Succ(I) to Pred(aDiff.Count) do begin
              NextCmd := aDiff.Items[J];
              if GetUseOp(NextCmd) = uoRemove then begin
                NextCmd.Find(PATH_KEY, Tmp);
                RemovePath := Tmp.AsString;
                if aSrc.FindPath(TJsonPtr.From(RemovePath)).EqualTo(Value) then begin
                  Cmd[OP_KEY] := MOVE_KEY;
                  Cmd[FROM_KEY] := RemovePath;
                  Cmd.Remove(VAL_KEY);
                  aDiff.Delete(J);
                  break;
                end;
              end;
            end;
          end;
        uoRemove: begin
            Cmd.Find(PATH_KEY, Tmp);
            RemovePath := Tmp.AsString;
            aSrc.FindPath(TJsonPtr.From(RemovePath), Value);
            for J := Succ(I) to Pred(aDiff.Count) do begin
              NextCmd := aDiff.Items[J];
              if GetUseOp(NextCmd) = uoAdd then begin
                NextCmd.Find(PATH_KEY, Tmp);
                AddPath := Tmp.AsString;
                if aDst.FindPath(TJsonPtr.From(AddPath)).EqualTo(Value) then begin
                  if IsPrefixPath(RemovePath, AddPath) then continue;
                  Cmd[OP_KEY] := MOVE_KEY;
                  Cmd[FROM_KEY] := RemovePath;
                  Cmd[PATH_KEY] := AddPath;
                  Cmd.Remove(VAL_KEY);
                  aDiff.Delete(J);
                  break;
                end;
              end;
            end;
          end;
      else
      end;
      Inc(I);
    end;
  end;

var
  Success: Boolean = False;

begin //todo: how to improve processing of arrays of structures?

  aDiff := nil;

  if (aSource = nil) or (aSource.Kind = jvkUnknown) then
    exit(drSourceMiss)
  else
    if (aTarget = nil) or (aTarget.Kind = jvkUnknown) then
      exit(drTargetMiss);

  TestRemove := doEmitTestOnRemove in aOptions;
  TestReplace := doEmitTestOnReplace in aOptions;
  UseArrayReplace := not (doDisableArrayReplace in aOptions);

  aDiff := TJsonNode.Create;
  try
    aDiff.AsArray;
    Success := DoDiff(aSource, aTarget);
    if Success and (doEnableMove in aOptions) then
      TryRemoveAdd2Move(aSource, aTarget);
  finally
    if not Success then
      FreeAndNil(aDiff);
  end;
  if Success then
    Result := drOk
  else
    Result := drFail;
end;

class function TJsonPatch.Diff(aSource, aTarget: TJsonNode; out aDiff: TJsonPatch;
  aOptions: TDiffOptions): TDiffResult;
var
  Node: TJsonNode = nil;
begin
  Result := Diff(aSource, aTarget, Node, aOptions);
  if Result = drOk then
    begin
      aDiff := TJsonPatch.Create;
      aDiff.FNode := Node;
      aDiff.FLoaded := True;
    end;
end;

class function TJsonPatch.Diff(aSource, aTarget: TJsonNode; out aDiff: string;
  aOptions: TDiffOptions): TDiffResult;
var
  Node: TJsonNode = nil;
begin
  aDiff := '';
  Result := Diff(aSource, aTarget, Node, aOptions);
  if Result = drOk then
    begin
      aDiff := Node.AsJson;
      Node.Free;
    end;
end;

{$PUSH}{$WARN 5089 OFF}
class function TJsonPatch.Diff(const aSource, aTarget: string; out aDiff: TJsonNode;
  aOptions: TDiffOptions): TDiffResult;
var
  Src, Dst: specialize TGUniqRef<TJsonNode>;
begin
  Src.Instance := TJsonNode.Load(aSource);
  Dst.Instance := TJsonNode.Load(aTarget);
  Result := Diff(Src.Instance, Dst.Instance, aDiff, aOptions);
end;

class function TJsonPatch.Diff(const aSource, aTarget: string; out aDiff: TJsonPatch;
  aOptions: TDiffOptions): TDiffResult;
var
  Node: TJsonNode = nil;
begin
  Result := Diff(aSource, aTarget, Node, aOptions);
  if Result = drOk then
    begin
      aDiff := TJsonPatch.Create;
      aDiff.FNode := Node;
      aDiff.FLoaded := True;
    end;
end;

class function TJsonPatch.Diff(const aSource, aTarget: string; out aDiff: string;
  aOptions: TDiffOptions): TDiffResult;
var
  Src, Dst: specialize TGUniqRef<TJsonNode>;
begin
  Src.Instance := TJsonNode.Load(aSource);
  Dst.Instance := TJsonNode.Load(aTarget);
  Result := Diff(Src.Instance, Dst.Instance, aDiff, aOptions);
end;

class function TJsonPatch.TryLoadPatch(const s: string; out p: TJsonPatch): Boolean;
begin
  p := TJsonPatch.Create;
  if not p.TryLoad(s) then
    begin
      FreeAndNil(p);
      exit(False);
    end;
  Result := True;
end;

class function TJsonPatch.LoadPatch(const s: string): TJsonPatch;
begin
  TryLoadPatch(s, Result);
end;

class function TJsonPatch.TryLoadPatchFile(const aFileName: string; out p: TJsonPatch): Boolean;
begin
  p := TJsonPatch.Create;
  try
    Result := p.TryLoadFile(aFileName);
  except
    Result := False;
    FreeAndNil(p);
    raise;
  end;
  if not Result then
    FreeAndNil(p);
end;

class function TJsonPatch.LoadPatchFile(const aFileName: string): TJsonPatch;
begin
  TryLoadPatchFile(aFileName, Result);
end;

class function TJsonPatch.Patch(p: TJsonPatch; var aTarget: string): TPatchResult;
begin
  Result := p.Apply(aTarget);
end;

class function TJsonPatch.Patch(p: TJsonNode; var aTarget: string): TPatchResult;
var
  LocPatch: specialize TGAutoRef<TJsonPatch>;
begin
  LocPatch.Instance.Load(p);
  Result := LocPatch.Instance.Apply(aTarget);
end;

class function TJsonPatch.Patch(const aPatch: string; var aTarget: string): TPatchResult;
var
  LocPatch: specialize TGAutoRef<TJsonPatch>;
begin
  if not LocPatch.Instance.TryLoad(aPatch) then
    exit(prPatchMiss);
  Result := LocPatch.Instance.Apply(aTarget);
end;

class function TJsonPatch.Patch(const aPatch: string; aTarget: TJsonNode): TPatchResult;
var
  LocPatch: specialize TGAutoRef<TJsonPatch>;
begin
  if not LocPatch.Instance.TryLoad(aPatch) then
    exit(prPatchMiss);
  Result := LocPatch.Instance.Apply(aTarget);
end;

class function TJsonPatch.PatchFile(p: TJsonPatch; const aTargetFileName: string): TPatchResult;
var
  LocTarget: specialize TGUniqRef<TJsonNode>;
begin
  LocTarget.Instance := TJsonNode.LoadFromFile(aTargetFileName);
  if not LocTarget.HasInstance then
    exit(prTargetMiss);
  Result := p.Apply(LocTarget.Instance);
  if Result = prOk then
    LocTarget.Instance.SaveToFile(aTargetFileName);
end;

class function TJsonPatch.PatchFile(const aPatch: string; const aTargetFileName: string): TPatchResult;
var
  LocPatch: specialize TGAutoRef<TJsonPatch>;
begin
  if not LocPatch.Instance.TryLoad(aPatch) then
    exit(prPatchMiss);
  Result := PatchFile(LocPatch.Instance, aTargetFileName);
end;
{$POP}

destructor TJsonPatch.Destroy;
begin
  FNode.Free;
  inherited;
end;

procedure TJsonPatch.Clear;
begin
  FreeAndNil(FNode);
  FLoaded := False;
  FValidated := False;
end;

function TJsonPatch.TryLoad(const s: string): Boolean;
var
  Node: TJsonNode = nil;
begin
  if not TJsonNode.TryParse(s, Node) then
    exit(False);
  Clear;
  FNode := Node;
  FLoaded := True;
  Result := True;
end;

function TJsonPatch.TryLoad(aStream: TStream; aCount: SizeInt): Boolean;
var
  Node: TJsonNode = nil;
begin
  if not TJsonNode.TryParse(aStream, aCount, Node) then
    exit(False);
  Clear;
  FNode := Node;
  FLoaded := True;
  Result := True;
end;

function TJsonPatch.TryLoadFile(const aFileName: string): Boolean;
var
  Node: TJsonNode = nil;
begin
  if not TJsonNode.TryParseFile(aFileName, Node) then
    exit(False);
  Clear;
  FNode := Node;
  FLoaded := True;
  Result := True;
end;

procedure TJsonPatch.Load(aNode: TJsonNode);
begin
  Clear;
  FNode := aNode.Clone;
  FLoaded := True;
end;

function TJsonPatch.Validate: Boolean;
begin
  if not Loaded then
    exit(False);
  FValidated := SeemsValidPatch(FNode);
  Result := FValidated;
end;

{$PUSH}{$WARN 5089 OFF}
function TJsonPatch.Apply(aTarget: TJsonNode): TPatchResult;
var
  CopyNode, CurrNode, TmpNode: TJsonNode;
  I: SizeInt;
  PathFrom, PathTo: TStringArray;
begin
  if not Loaded then
    exit(prPatchMiss);
  if (aTarget = nil) or (aTarget.Kind = jvkUnknown) then
    exit(prTargetMiss);
  if Validated then
    exit(ApplyValidated(aTarget));
  if not FNode.IsArray then
    exit(prMalformPatch);
  CopyNode := aTarget.Clone;
  try
    for I := 0 to Pred(FNode.Count) do
      begin
        CurrNode := FNode.Items[I];
        if not FindOp(CurrNode, TmpNode) then
          exit(prMalformPatch);
        case TmpNode.AsString of
          ADD_KEY:
            begin
              if not GetValAndPath(CurrNode, TmpNode, PathTo) then
                exit(prMalformPatch);
              if not TryAdd(CopyNode, TmpNode, PathTo) then
                exit(prFail);
            end;
          COPY_KEY:
            begin
              if not GetCopyPaths(CurrNode, TmpNode, PathFrom, PathTo) then
                exit(prMalformPatch);
              if not FindCopyValue(CopyNode, PathFrom, TmpNode) then
                exit(prFail);
              if not TryAdd(CopyNode, TmpNode, PathTo) then
                exit(prFail);
            end;
          MOVE_KEY:
            begin
              if not GetMovePaths(CurrNode, TmpNode, PathFrom, PathTo) then
                exit(prMalformPatch);
              if TStrHelper.Same(PathFrom, PathTo) then
                continue;
              if not TryExtract(CopyNode, PathFrom, TmpNode) then
                exit(prFail);
              if not TryMove(CopyNode, TmpNode, PathTo) then
                begin
                  TmpNode.Free;
                  exit(prFail);
                end;
            end;
          REMOVE_KEY:
            begin
              if not GetPath(CurrNode, TmpNode, PathTo) then
                exit(prMalformPatch);
              if not TryRemove(CopyNode, PathTo) then
                exit(prFail);
            end;
          REPLACE_KEY:
            begin
              if not GetValAndPath(CurrNode, TmpNode, PathFrom) then
                exit(prMalformPatch);
              if not TryReplace(CopyNode, TmpNode, PathFrom) then
                exit(prFail);
            end;
          TEST_KEY:
            begin
              if not GetValAndPath(CurrNode, TmpNode, PathFrom) then
                exit(prMalformPatch);
              if not TryTest(CopyNode, TmpNode, PathFrom) then
                exit(prFail);
            end;
        else
          exit(prMalformPatch);
        end;
      end;
    MoveNode(CopyNode, aTarget);
    Result := prOk;
  finally
    CopyNode.Free;
  end;
end;

function TJsonPatch.Apply(var aTarget: string): TPatchResult;
var
  LocTarget: specialize TGUniqRef<TJsonNode>;
begin
  LocTarget.Instance := TJsonNode.Load(aTarget);
  Result := Apply(LocTarget.Instance);
  if Result = prOk then
    aTarget := LocTarget.Instance.AsJson;
end;

{$POP}

function TJsonPatch.TryAsJson(out aJson: string): Boolean;
begin
  if not Loaded then
    exit(False);
  aJson := FNode.AsJson;
  Result := True;
end;

{
  A Pascal port of the Eisel-Lemire decimal-to-double approximation algorithm;
  https://github.com/lemire/fast_double_parser
}
const
  ELDBL_LOWEST_POWER  = -325;
  ELDBL_HIGHEST_POWER = 308;

{$PUSH}{$Q-}{$R-}{$J-}{$WARN 4080 OFF}
function TryBuildDoubleEiselLemire(aMantissa: QWord; const aPow10: Int64; aNeg: Boolean; out aValue: Double): Boolean; inline;
const
  TEN_POWER: array[0..22] of Double = (
    1e0,  1e1,  1e2,  1e3,  1e4,  1e5,  1e6,  1e7,  1e8,  1e9,  1e10, 1e11,
    1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22);

  EL_MANTIS_64: array[ELDBL_LOWEST_POWER..ELDBL_HIGHEST_POWER] of QWord = (
    QWord($a5ced43b7e3e9188), QWord($cf42894a5dce35ea), QWord($818995ce7aa0e1b2), QWord($a1ebfb4219491a1f),
    QWord($ca66fa129f9b60a6), QWord($fd00b897478238d0), QWord($9e20735e8cb16382), QWord($c5a890362fddbc62),
    QWord($f712b443bbd52b7b), QWord($9a6bb0aa55653b2d), QWord($c1069cd4eabe89f8), QWord($f148440a256e2c76),
    QWord($96cd2a865764dbca), QWord($bc807527ed3e12bc), QWord($eba09271e88d976b), QWord($93445b8731587ea3),
    QWord($b8157268fdae9e4c), QWord($e61acf033d1a45df), QWord($8fd0c16206306bab), QWord($b3c4f1ba87bc8696),
    QWord($e0b62e2929aba83c), QWord($8c71dcd9ba0b4925), QWord($af8e5410288e1b6f), QWord($db71e91432b1a24a),
    QWord($892731ac9faf056e), QWord($ab70fe17c79ac6ca), QWord($d64d3d9db981787d), QWord($85f0468293f0eb4e),
    QWord($a76c582338ed2621), QWord($d1476e2c07286faa), QWord($82cca4db847945ca), QWord($a37fce126597973c),
    QWord($cc5fc196fefd7d0c), QWord($ff77b1fcbebcdc4f), QWord($9faacf3df73609b1), QWord($c795830d75038c1d),
    QWord($f97ae3d0d2446f25), QWord($9becce62836ac577), QWord($c2e801fb244576d5), QWord($f3a20279ed56d48a),
    QWord($9845418c345644d6), QWord($be5691ef416bd60c), QWord($edec366b11c6cb8f), QWord($94b3a202eb1c3f39),
    QWord($b9e08a83a5e34f07), QWord($e858ad248f5c22c9), QWord($91376c36d99995be), QWord($b58547448ffffb2d),
    QWord($e2e69915b3fff9f9), QWord($8dd01fad907ffc3b), QWord($b1442798f49ffb4a), QWord($dd95317f31c7fa1d),
    QWord($8a7d3eef7f1cfc52), QWord($ad1c8eab5ee43b66), QWord($d863b256369d4a40), QWord($873e4f75e2224e68),
    QWord($a90de3535aaae202), QWord($d3515c2831559a83), QWord($8412d9991ed58091), QWord($a5178fff668ae0b6),
    QWord($ce5d73ff402d98e3), QWord($80fa687f881c7f8e), QWord($a139029f6a239f72), QWord($c987434744ac874e),
    QWord($fbe9141915d7a922), QWord($9d71ac8fada6c9b5), QWord($c4ce17b399107c22), QWord($f6019da07f549b2b),
    QWord($99c102844f94e0fb), QWord($c0314325637a1939), QWord($f03d93eebc589f88), QWord($96267c7535b763b5),
    QWord($bbb01b9283253ca2), QWord($ea9c227723ee8bcb), QWord($92a1958a7675175f), QWord($b749faed14125d36),
    QWord($e51c79a85916f484), QWord($8f31cc0937ae58d2), QWord($b2fe3f0b8599ef07), QWord($dfbdcece67006ac9),
    QWord($8bd6a141006042bd), QWord($aecc49914078536d), QWord($da7f5bf590966848), QWord($888f99797a5e012d),
    QWord($aab37fd7d8f58178), QWord($d5605fcdcf32e1d6), QWord($855c3be0a17fcd26), QWord($a6b34ad8c9dfc06f),
    QWord($d0601d8efc57b08b), QWord($823c12795db6ce57), QWord($a2cb1717b52481ed), QWord($cb7ddcdda26da268),
    QWord($fe5d54150b090b02), QWord($9efa548d26e5a6e1), QWord($c6b8e9b0709f109a), QWord($f867241c8cc6d4c0),
    QWord($9b407691d7fc44f8), QWord($c21094364dfb5636), QWord($f294b943e17a2bc4), QWord($979cf3ca6cec5b5a),
    QWord($bd8430bd08277231), QWord($ece53cec4a314ebd), QWord($940f4613ae5ed136), QWord($b913179899f68584),
    QWord($e757dd7ec07426e5), QWord($9096ea6f3848984f), QWord($b4bca50b065abe63), QWord($e1ebce4dc7f16dfb),
    QWord($8d3360f09cf6e4bd), QWord($b080392cc4349dec), QWord($dca04777f541c567), QWord($89e42caaf9491b60),
    QWord($ac5d37d5b79b6239), QWord($d77485cb25823ac7), QWord($86a8d39ef77164bc), QWord($a8530886b54dbdeb),
    QWord($d267caa862a12d66), QWord($8380dea93da4bc60), QWord($a46116538d0deb78), QWord($cd795be870516656),
    QWord($806bd9714632dff6), QWord($a086cfcd97bf97f3), QWord($c8a883c0fdaf7df0), QWord($fad2a4b13d1b5d6c),
    QWord($9cc3a6eec6311a63), QWord($c3f490aa77bd60fc), QWord($f4f1b4d515acb93b), QWord($991711052d8bf3c5),
    QWord($bf5cd54678eef0b6), QWord($ef340a98172aace4), QWord($9580869f0e7aac0e), QWord($bae0a846d2195712),
    QWord($e998d258869facd7), QWord($91ff83775423cc06), QWord($b67f6455292cbf08), QWord($e41f3d6a7377eeca),
    QWord($8e938662882af53e), QWord($b23867fb2a35b28d), QWord($dec681f9f4c31f31), QWord($8b3c113c38f9f37e),
    QWord($ae0b158b4738705e), QWord($d98ddaee19068c76), QWord($87f8a8d4cfa417c9), QWord($a9f6d30a038d1dbc),
    QWord($d47487cc8470652b), QWord($84c8d4dfd2c63f3b), QWord($a5fb0a17c777cf09), QWord($cf79cc9db955c2cc),
    QWord($81ac1fe293d599bf), QWord($a21727db38cb002f), QWord($ca9cf1d206fdc03b), QWord($fd442e4688bd304a),
    QWord($9e4a9cec15763e2e), QWord($c5dd44271ad3cdba), QWord($f7549530e188c128), QWord($9a94dd3e8cf578b9),
    QWord($c13a148e3032d6e7), QWord($f18899b1bc3f8ca1), QWord($96f5600f15a7b7e5), QWord($bcb2b812db11a5de),
    QWord($ebdf661791d60f56), QWord($936b9fcebb25c995), QWord($b84687c269ef3bfb), QWord($e65829b3046b0afa),
    QWord($8ff71a0fe2c2e6dc), QWord($b3f4e093db73a093), QWord($e0f218b8d25088b8), QWord($8c974f7383725573),
    QWord($afbd2350644eeacf), QWord($dbac6c247d62a583), QWord($894bc396ce5da772), QWord($ab9eb47c81f5114f),
    QWord($d686619ba27255a2), QWord($8613fd0145877585), QWord($a798fc4196e952e7), QWord($d17f3b51fca3a7a0),
    QWord($82ef85133de648c4), QWord($a3ab66580d5fdaf5), QWord($cc963fee10b7d1b3), QWord($ffbbcfe994e5c61f),
    QWord($9fd561f1fd0f9bd3), QWord($c7caba6e7c5382c8), QWord($f9bd690a1b68637b), QWord($9c1661a651213e2d),
    QWord($c31bfa0fe5698db8), QWord($f3e2f893dec3f126), QWord($986ddb5c6b3a76b7), QWord($be89523386091465),
    QWord($ee2ba6c0678b597f), QWord($94db483840b717ef), QWord($ba121a4650e4ddeb), QWord($e896a0d7e51e1566),
    QWord($915e2486ef32cd60), QWord($b5b5ada8aaff80b8), QWord($e3231912d5bf60e6), QWord($8df5efabc5979c8f),
    QWord($b1736b96b6fd83b3), QWord($ddd0467c64bce4a0), QWord($8aa22c0dbef60ee4), QWord($ad4ab7112eb3929d),
    QWord($d89d64d57a607744), QWord($87625f056c7c4a8b), QWord($a93af6c6c79b5d2d), QWord($d389b47879823479),
    QWord($843610cb4bf160cb), QWord($a54394fe1eedb8fe), QWord($ce947a3da6a9273e), QWord($811ccc668829b887),
    QWord($a163ff802a3426a8), QWord($c9bcff6034c13052), QWord($fc2c3f3841f17c67), QWord($9d9ba7832936edc0),
    QWord($c5029163f384a931), QWord($f64335bcf065d37d), QWord($99ea0196163fa42e), QWord($c06481fb9bcf8d39),
    QWord($f07da27a82c37088), QWord($964e858c91ba2655), QWord($bbe226efb628afea), QWord($eadab0aba3b2dbe5),
    QWord($92c8ae6b464fc96f), QWord($b77ada0617e3bbcb), QWord($e55990879ddcaabd), QWord($8f57fa54c2a9eab6),
    QWord($b32df8e9f3546564), QWord($dff9772470297ebd), QWord($8bfbea76c619ef36), QWord($aefae51477a06b03),
    QWord($dab99e59958885c4), QWord($88b402f7fd75539b), QWord($aae103b5fcd2a881), QWord($d59944a37c0752a2),
    QWord($857fcae62d8493a5), QWord($a6dfbd9fb8e5b88e), QWord($d097ad07a71f26b2), QWord($825ecc24c873782f),
    QWord($a2f67f2dfa90563b), QWord($cbb41ef979346bca), QWord($fea126b7d78186bc), QWord($9f24b832e6b0f436),
    QWord($c6ede63fa05d3143), QWord($f8a95fcf88747d94), QWord($9b69dbe1b548ce7c), QWord($c24452da229b021b),
    QWord($f2d56790ab41c2a2), QWord($97c560ba6b0919a5), QWord($bdb6b8e905cb600f), QWord($ed246723473e3813),
    QWord($9436c0760c86e30b), QWord($b94470938fa89bce), QWord($e7958cb87392c2c2), QWord($90bd77f3483bb9b9),
    QWord($b4ecd5f01a4aa828), QWord($e2280b6c20dd5232), QWord($8d590723948a535f), QWord($b0af48ec79ace837),
    QWord($dcdb1b2798182244), QWord($8a08f0f8bf0f156b), QWord($ac8b2d36eed2dac5), QWord($d7adf884aa879177),
    QWord($86ccbb52ea94baea), QWord($a87fea27a539e9a5), QWord($d29fe4b18e88640e), QWord($83a3eeeef9153e89),
    QWord($a48ceaaab75a8e2b), QWord($cdb02555653131b6), QWord($808e17555f3ebf11), QWord($a0b19d2ab70e6ed6),
    QWord($c8de047564d20a8b), QWord($fb158592be068d2e), QWord($9ced737bb6c4183d), QWord($c428d05aa4751e4c),
    QWord($f53304714d9265df), QWord($993fe2c6d07b7fab), QWord($bf8fdb78849a5f96), QWord($ef73d256a5c0f77c),
    QWord($95a8637627989aad), QWord($bb127c53b17ec159), QWord($e9d71b689dde71af), QWord($9226712162ab070d),
    QWord($b6b00d69bb55c8d1), QWord($e45c10c42a2b3b05), QWord($8eb98a7a9a5b04e3), QWord($b267ed1940f1c61c),
    QWord($df01e85f912e37a3), QWord($8b61313bbabce2c6), QWord($ae397d8aa96c1b77), QWord($d9c7dced53c72255),
    QWord($881cea14545c7575), QWord($aa242499697392d2), QWord($d4ad2dbfc3d07787), QWord($84ec3c97da624ab4),
    QWord($a6274bbdd0fadd61), QWord($cfb11ead453994ba), QWord($81ceb32c4b43fcf4), QWord($a2425ff75e14fc31),
    QWord($cad2f7f5359a3b3e), QWord($fd87b5f28300ca0d), QWord($9e74d1b791e07e48), QWord($c612062576589dda),
    QWord($f79687aed3eec551), QWord($9abe14cd44753b52), QWord($c16d9a0095928a27), QWord($f1c90080baf72cb1),
    QWord($971da05074da7bee), QWord($bce5086492111aea), QWord($ec1e4a7db69561a5), QWord($9392ee8e921d5d07),
    QWord($b877aa3236a4b449), QWord($e69594bec44de15b), QWord($901d7cf73ab0acd9), QWord($b424dc35095cd80f),
    QWord($e12e13424bb40e13), QWord($8cbccc096f5088cb), QWord($afebff0bcb24aafe), QWord($dbe6fecebdedd5be),
    QWord($89705f4136b4a597), QWord($abcc77118461cefc), QWord($d6bf94d5e57a42bc), QWord($8637bd05af6c69b5),
    QWord($a7c5ac471b478423), QWord($d1b71758e219652b), QWord($83126e978d4fdf3b), QWord($a3d70a3d70a3d70a),
    QWord($cccccccccccccccc), QWord($8000000000000000), QWord($a000000000000000), QWord($c800000000000000),
    QWord($fa00000000000000), QWord($9c40000000000000), QWord($c350000000000000), QWord($f424000000000000),
    QWord($9896800000000000), QWord($bebc200000000000), QWord($ee6b280000000000), QWord($9502f90000000000),
    QWord($ba43b74000000000), QWord($e8d4a51000000000), QWord($9184e72a00000000), QWord($b5e620f480000000),
    QWord($e35fa931a0000000), QWord($8e1bc9bf04000000), QWord($b1a2bc2ec5000000), QWord($de0b6b3a76400000),
    QWord($8ac7230489e80000), QWord($ad78ebc5ac620000), QWord($d8d726b7177a8000), QWord($878678326eac9000),
    QWord($a968163f0a57b400), QWord($d3c21bcecceda100), QWord($84595161401484a0), QWord($a56fa5b99019a5c8),
    QWord($cecb8f27f4200f3a), QWord($813f3978f8940984), QWord($a18f07d736b90be5), QWord($c9f2c9cd04674ede),
    QWord($fc6f7c4045812296), QWord($9dc5ada82b70b59d), QWord($c5371912364ce305), QWord($f684df56c3e01bc6),
    QWord($9a130b963a6c115c), QWord($c097ce7bc90715b3), QWord($f0bdc21abb48db20), QWord($96769950b50d88f4),
    QWord($bc143fa4e250eb31), QWord($eb194f8e1ae525fd), QWord($92efd1b8d0cf37be), QWord($b7abc627050305ad),
    QWord($e596b7b0c643c719), QWord($8f7e32ce7bea5c6f), QWord($b35dbf821ae4f38b), QWord($e0352f62a19e306e),
    QWord($8c213d9da502de45), QWord($af298d050e4395d6), QWord($daf3f04651d47b4c), QWord($88d8762bf324cd0f),
    QWord($ab0e93b6efee0053), QWord($d5d238a4abe98068), QWord($85a36366eb71f041), QWord($a70c3c40a64e6c51),
    QWord($d0cf4b50cfe20765), QWord($82818f1281ed449f), QWord($a321f2d7226895c7), QWord($cbea6f8ceb02bb39),
    QWord($fee50b7025c36a08), QWord($9f4f2726179a2245), QWord($c722f0ef9d80aad6), QWord($f8ebad2b84e0d58b),
    QWord($9b934c3b330c8577), QWord($c2781f49ffcfa6d5), QWord($f316271c7fc3908a), QWord($97edd871cfda3a56),
    QWord($bde94e8e43d0c8ec), QWord($ed63a231d4c4fb27), QWord($945e455f24fb1cf8), QWord($b975d6b6ee39e436),
    QWord($e7d34c64a9c85d44), QWord($90e40fbeea1d3a4a), QWord($b51d13aea4a488dd), QWord($e264589a4dcdab14),
    QWord($8d7eb76070a08aec), QWord($b0de65388cc8ada8), QWord($dd15fe86affad912), QWord($8a2dbf142dfcc7ab),
    QWord($acb92ed9397bf996), QWord($d7e77a8f87daf7fb), QWord($86f0ac99b4e8dafd), QWord($a8acd7c0222311bc),
    QWord($d2d80db02aabd62b), QWord($83c7088e1aab65db), QWord($a4b8cab1a1563f52), QWord($cde6fd5e09abcf26),
    QWord($80b05e5ac60b6178), QWord($a0dc75f1778e39d6), QWord($c913936dd571c84c), QWord($fb5878494ace3a5f),
    QWord($9d174b2dcec0e47b), QWord($c45d1df942711d9a), QWord($f5746577930d6500), QWord($9968bf6abbe85f20),
    QWord($bfc2ef456ae276e8), QWord($efb3ab16c59b14a2), QWord($95d04aee3b80ece5), QWord($bb445da9ca61281f),
    QWord($ea1575143cf97226), QWord($924d692ca61be758), QWord($b6e0c377cfa2e12e), QWord($e498f455c38b997a),
    QWord($8edf98b59a373fec), QWord($b2977ee300c50fe7), QWord($df3d5e9bc0f653e1), QWord($8b865b215899f46c),
    QWord($ae67f1e9aec07187), QWord($da01ee641a708de9), QWord($884134fe908658b2), QWord($aa51823e34a7eede),
    QWord($d4e5e2cdc1d1ea96), QWord($850fadc09923329e), QWord($a6539930bf6bff45), QWord($cfe87f7cef46ff16),
    QWord($81f14fae158c5f6e), QWord($a26da3999aef7749), QWord($cb090c8001ab551c), QWord($fdcb4fa002162a63),
    QWord($9e9f11c4014dda7e), QWord($c646d63501a1511d), QWord($f7d88bc24209a565), QWord($9ae757596946075f),
    QWord($c1a12d2fc3978937), QWord($f209787bb47d6b84), QWord($9745eb4d50ce6332), QWord($bd176620a501fbff),
    QWord($ec5d3fa8ce427aff), QWord($93ba47c980e98cdf), QWord($b8a8d9bbe123f017), QWord($e6d3102ad96cec1d),
    QWord($9043ea1ac7e41392), QWord($b454e4a179dd1877), QWord($e16a1dc9d8545e94), QWord($8ce2529e2734bb1d),
    QWord($b01ae745b101e9e4), QWord($dc21a1171d42645d), QWord($899504ae72497eba), QWord($abfa45da0edbde69),
    QWord($d6f8d7509292d603), QWord($865b86925b9bc5c2), QWord($a7f26836f282b732), QWord($d1ef0244af2364ff),
    QWord($8335616aed761f1f), QWord($a402b9c5a8d3a6e7), QWord($cd036837130890a1), QWord($802221226be55a64),
    QWord($a02aa96b06deb0fd), QWord($c83553c5c8965d3d), QWord($fa42a8b73abbf48c), QWord($9c69a97284b578d7),
    QWord($c38413cf25e2d70d), QWord($f46518c2ef5b8cd1), QWord($98bf2f79d5993802), QWord($beeefb584aff8603),
    QWord($eeaaba2e5dbf6784), QWord($952ab45cfa97a0b2), QWord($ba756174393d88df), QWord($e912b9d1478ceb17),
    QWord($91abb422ccb812ee), QWord($b616a12b7fe617aa), QWord($e39c49765fdf9d94), QWord($8e41ade9fbebc27d),
    QWord($b1d219647ae6b31c), QWord($de469fbd99a05fe3), QWord($8aec23d680043bee), QWord($ada72ccc20054ae9),
    QWord($d910f7ff28069da4), QWord($87aa9aff79042286), QWord($a99541bf57452b28), QWord($d3fa922f2d1675f2),
    QWord($847c9b5d7c2e09b7), QWord($a59bc234db398c25), QWord($cf02b2c21207ef2e), QWord($8161afb94b44f57d),
    QWord($a1ba1ba79e1632dc), QWord($ca28a291859bbf93), QWord($fcb2cb35e702af78), QWord($9defbf01b061adab),
    QWord($c56baec21c7a1916), QWord($f6c69a72a3989f5b), QWord($9a3c2087a63f6399), QWord($c0cb28a98fcf3c7f),
    QWord($f0fdf2d3f3c30b9f), QWord($969eb7c47859e743), QWord($bc4665b596706114), QWord($eb57ff22fc0c7959),
    QWord($9316ff75dd87cbd8), QWord($b7dcbf5354e9bece), QWord($e5d3ef282a242e81), QWord($8fa475791a569d10),
    QWord($b38d92d760ec4455), QWord($e070f78d3927556a), QWord($8c469ab843b89562), QWord($af58416654a6babb),
    QWord($db2e51bfe9d0696a), QWord($88fcf317f22241e2), QWord($ab3c2fddeeaad25a), QWord($d60b3bd56a5586f1),
    QWord($85c7056562757456), QWord($a738c6bebb12d16c), QWord($d106f86e69d785c7), QWord($82a45b450226b39c),
    QWord($a34d721642b06084), QWord($cc20ce9bd35c78a5), QWord($ff290242c83396ce), QWord($9f79a169bd203e41),
    QWord($c75809c42c684dd1), QWord($f92e0c3537826145), QWord($9bbcc7a142b17ccb), QWord($c2abf989935ddbfe),
    QWord($f356f7ebf83552fe), QWord($98165af37b2153de), QWord($be1bf1b059e9a8d6), QWord($eda2ee1c7064130c),
    QWord($9485d4d1c63e8be7), QWord($b9a74a0637ce2ee1), QWord($e8111c87c5c1ba99), QWord($910ab1d4db9914a0),
    QWord($b54d5e4a127f59c8), QWord($e2a0b5dc971f303a), QWord($8da471a9de737e24), QWord($b10d8e1456105dad),
    QWord($dd50f1996b947518), QWord($8a5296ffe33cc92f), QWord($ace73cbfdc0bfb7b), QWord($d8210befd30efa5a),
    QWord($8714a775e3e95c78), QWord($a8d9d1535ce3b396), QWord($d31045a8341ca07c), QWord($83ea2b892091e44d),
    QWord($a4e4b66b68b65d60), QWord($ce1de40642e3f4b9), QWord($80d2ae83e9ce78f3), QWord($a1075a24e4421730),
    QWord($c94930ae1d529cfc), QWord($fb9b7cd9a4a7443c), QWord($9d412e0806e88aa5), QWord($c491798a08a2ad4e),
    QWord($f5b5d7ec8acb58a2), QWord($9991a6f3d6bf1765), QWord($bff610b0cc6edd3f), QWord($eff394dcff8a948e),
    QWord($95f83d0a1fb69cd9), QWord($bb764c4ca7a4440f), QWord($ea53df5fd18d5513), QWord($92746b9be2f8552c),
    QWord($b7118682dbb66a77), QWord($e4d5e82392a40515), QWord($8f05b1163ba6832d), QWord($b2c71d5bca9023f8),
    QWord($df78e4b2bd342cf6), QWord($8bab8eefb6409c1a), QWord($ae9672aba3d0c320), QWord($da3c0f568cc4f3e8),
    QWord($8865899617fb1871), QWord($aa7eebfb9df9de8d), QWord($d51ea6fa85785631), QWord($8533285c936b35de),
    QWord($a67ff273b8460356), QWord($d01fef10a657842c), QWord($8213f56a67f6b29b), QWord($a298f2c501f45f42),
    QWord($cb3f2f7642717713), QWord($fe0efb53d30dd4d7), QWord($9ec95d1463e8a506), QWord($c67bb4597ce2ce48),
    QWord($f81aa16fdc1b81da), QWord($9b10a4e5e9913128), QWord($c1d4ce1f63f57d72), QWord($f24a01a73cf2dccf),
    QWord($976e41088617ca01), QWord($bd49d14aa79dbc82), QWord($ec9c459d51852ba2), QWord($93e1ab8252f33b45),
    QWord($b8da1662e7b00a17), QWord($e7109bfba19c0c9d), QWord($906a617d450187e2), QWord($b484f9dc9641e9da),
    QWord($e1a63853bbd26451), QWord($8d07e33455637eb2), QWord($b049dc016abc5e5f), QWord($dc5c5301c56b75f7),
    QWord($89b9b3e11b6329ba), QWord($ac2820d9623bf429), QWord($d732290fbacaf133), QWord($867f59a9d4bed6c0),
    QWord($a81f301449ee8c70), QWord($d226fc195c6a2f8c), QWord($83585d8fd9c25db7), QWord($a42e74f3d032f525),
    QWord($cd3a1230c43fb26f), QWord($80444b5e7aa7cf85), QWord($a0555e361951c366), QWord($c86ab5c39fa63440),
    QWord($fa856334878fc150), QWord($9c935e00d4b9d8d2), QWord($c3b8358109e84f07), QWord($f4a642e14c6262c8),
    QWord($98e7e9cccfbd7dbd), QWord($bf21e44003acdd2c), QWord($eeea5d5004981478), QWord($95527a5202df0ccb),
    QWord($baa718e68396cffd), QWord($e950df20247c83fd), QWord($91d28b7416cdd27e), QWord($b6472e511c81471d),
    QWord($e3d8f9e563a198e5), QWord($8e679c2f5e44ff8f));

  EL_MANTIS_128: array[ELDBL_LOWEST_POWER..ELDBL_HIGHEST_POWER] of QWord = (
    QWord($419ea3bd35385e2d), QWord($52064cac828675b9), QWord($7343efebd1940993), QWord($1014ebe6c5f90bf8),
    QWord($d41a26e077774ef6), QWord($8920b098955522b4), QWord($55b46e5f5d5535b0), QWord($eb2189f734aa831d),
    QWord($a5e9ec7501d523e4), QWord($47b233c92125366e), QWord($999ec0bb696e840a), QWord($c00670ea43ca250d),
    QWord($380406926a5e5728), QWord($c605083704f5ecf2), QWord($f7864a44c633682e), QWord($7ab3ee6afbe0211d),
    QWord($5960ea05bad82964), QWord($6fb92487298e33bd), QWord($a5d3b6d479f8e056), QWord($8f48a4899877186c),
    QWord($331acdabfe94de87), QWord($9ff0c08b7f1d0b14), QWord($7ecf0ae5ee44dd9),  QWord($c9e82cd9f69d6150),
    QWord($be311c083a225cd2), QWord($6dbd630a48aaf406), QWord($92cbbccdad5b108),  QWord($25bbf56008c58ea5),
    QWord($af2af2b80af6f24e), QWord($1af5af660db4aee1), QWord($50d98d9fc890ed4d), QWord($e50ff107bab528a0),
    QWord($1e53ed49a96272c8), QWord($25e8e89c13bb0f7a), QWord($77b191618c54e9ac), QWord($d59df5b9ef6a2417),
    QWord($4b0573286b44ad1d), QWord($4ee367f9430aec32), QWord($229c41f793cda73f), QWord($6b43527578c1110f),
    QWord($830a13896b78aaa9), QWord($23cc986bc656d553), QWord($2cbfbe86b7ec8aa8), QWord($7bf7d71432f3d6a9),
    QWord($daf5ccd93fb0cc53), QWord($d1b3400f8f9cff68), QWord($23100809b9c21fa1), QWord($abd40a0c2832a78a),
    QWord($16c90c8f323f516c), QWord($ae3da7d97f6792e3), QWord($99cd11cfdf41779c), QWord($40405643d711d583),
    QWord($482835ea666b2572), QWord($da3243650005eecf), QWord($90bed43e40076a82), QWord($5a7744a6e804a291),
    QWord($711515d0a205cb36), QWord($d5a5b44ca873e03),  QWord($e858790afe9486c2), QWord($626e974dbe39a872),
    QWord($fb0a3d212dc8128f), QWord($7ce66634bc9d0b99), QWord($1c1fffc1ebc44e80), QWord($a327ffb266b56220),
    QWord($4bf1ff9f0062baa8), QWord($6f773fc3603db4a9), QWord($cb550fb4384d21d3), QWord($7e2a53a146606a48),
    QWord($2eda7444cbfc426d), QWord($fa911155fefb5308), QWord($793555ab7eba27ca), QWord($4bc1558b2f3458de),
    QWord($9eb1aaedfb016f16), QWord($465e15a979c1cadc), QWord($bfacd89ec191ec9),  QWord($cef980ec671f667b),
    QWord($82b7e12780e7401a), QWord($d1b2ecb8b0908810), QWord($861fa7e6dcb4aa15), QWord($67a791e093e1d49a),
    QWord($e0c8bb2c5c6d24e0), QWord($58fae9f773886e18), QWord($af39a475506a899e), QWord($6d8406c952429603),
    QWord($c8e5087ba6d33b83), QWord($fb1e4a9a90880a64), QWord($5cf2eea09a55067f), QWord($f42faa48c0ea481e),
    QWord($f13b94daf124da26), QWord($76c53d08d6b70858), QWord($54768c4b0c64ca6e), QWord($a9942f5dcf7dfd09),
    QWord($d3f93b35435d7c4c), QWord($c47bc5014a1a6daf), QWord($359ab6419ca1091b), QWord($c30163d203c94b62),
    QWord($79e0de63425dcf1d), QWord($985915fc12f542e4), QWord($3e6f5b7b17b2939d), QWord($a705992ceecf9c42),
    QWord($50c6ff782a838353), QWord($a4f8bf5635246428), QWord($871b7795e136be99), QWord($28e2557b59846e3f),
    QWord($331aeada2fe589cf), QWord($3ff0d2c85def7621), QWord($fed077a756b53a9),  QWord($d3e8495912c62894),
    QWord($64712dd7abbbd95c), QWord($bd8d794d96aacfb3), QWord($ecf0d7a0fc5583a0), QWord($f41686c49db57244),
    QWord($311c2875c522ced5), QWord($7d633293366b828b), QWord($ae5dff9c02033197), QWord($d9f57f830283fdfc),
    QWord($d072df63c324fd7b), QWord($4247cb9e59f71e6d), QWord($52d9be85f074e608), QWord($67902e276c921f8b),
    QWord($ba1cd8a3db53b6),   QWord($80e8a40eccd228a4), QWord($6122cd128006b2cd), QWord($796b805720085f81),
    QWord($cbe3303674053bb0), QWord($bedbfc4411068a9c), QWord($ee92fb5515482d44), QWord($751bdd152d4d1c4a),
    QWord($d262d45a78a0635d), QWord($86fb897116c87c34), QWord($d45d35e6ae3d4da0), QWord($8974836059cca109),
    QWord($2bd1a438703fc94b), QWord($7b6306a34627ddcf), QWord($1a3bc84c17b1d542), QWord($20caba5f1d9e4a93),
    QWord($547eb47b7282ee9c), QWord($e99e619a4f23aa43), QWord($6405fa00e2ec94d4), QWord($de83bc408dd3dd04),
    QWord($9624ab50b148d445), QWord($3badd624dd9b0957), QWord($e54ca5d70a80e5d6), QWord($5e9fcf4ccd211f4c),
    QWord($7647c3200069671f), QWord($29ecd9f40041e073), QWord($f468107100525890), QWord($7182148d4066eeb4),
    QWord($c6f14cd848405530), QWord($b8ada00e5a506a7c), QWord($a6d90811f0e4851c), QWord($908f4a166d1da663),
    QWord($9a598e4e043287fe), QWord($40eff1e1853f29fd), QWord($d12bee59e68ef47c), QWord($82bb74f8301958ce),
    QWord($e36a52363c1faf01), QWord($dc44e6c3cb279ac1), QWord($29ab103a5ef8c0b9), QWord($7415d448f6b6f0e7),
    QWord($111b495b3464ad21), QWord($cab10dd900beec34), QWord($3d5d514f40eea742), QWord($cb4a5a3112a5112),
    QWord($47f0e785eaba72ab), QWord($59ed216765690f56), QWord($306869c13ec3532c), QWord($1e414218c73a13fb),
    QWord($e5d1929ef90898fa), QWord($df45f746b74abf39), QWord($6b8bba8c328eb783), QWord($66ea92f3f326564),
    QWord($c80a537b0efefebd), QWord($bd06742ce95f5f36), QWord($2c48113823b73704), QWord($f75a15862ca504c5),
    QWord($9a984d73dbe722fb), QWord($c13e60d0d2e0ebba), QWord($318df905079926a8), QWord($fdf17746497f7052),
    QWord($feb6ea8bedefa633), QWord($fe64a52ee96b8fc0), QWord($3dfdce7aa3c673b0), QWord($6bea10ca65c084e),
    QWord($486e494fcff30a62), QWord($5a89dba3c3efccfa), QWord($f89629465a75e01c), QWord($f6bbb397f1135823),
    QWord($746aa07ded582e2c), QWord($a8c2a44eb4571cdc), QWord($92f34d62616ce413), QWord($77b020baf9c81d17),
    QWord($ace1474dc1d122e),  QWord($d819992132456ba),  QWord($10e1fff697ed6c69), QWord($ca8d3ffa1ef463c1),
    QWord($bd308ff8a6b17cb2), QWord($ac7cb3f6d05ddbde), QWord($6bcdf07a423aa96b), QWord($86c16c98d2c953c6),
    QWord($e871c7bf077ba8b7), QWord($11471cd764ad4972), QWord($d598e40d3dd89bcf), QWord($4aff1d108d4ec2c3),
    QWord($cedf722a585139ba), QWord($c2974eb4ee658828), QWord($733d226229feea32), QWord($806357d5a3f525f),
    QWord($ca07c2dcb0cf26f7), QWord($fc89b393dd02f0b5), QWord($bbac2078d443ace2), QWord($d54b944b84aa4c0d),
    QWord($a9e795e65d4df11),  QWord($4d4617b5ff4a16d5), QWord($504bced1bf8e4e45), QWord($e45ec2862f71e1d6),
    QWord($5d767327bb4e5a4c), QWord($3a6a07f8d510f86f), QWord($890489f70a55368b), QWord($2b45ac74ccea842e),
    QWord($3b0b8bc90012929d), QWord($9ce6ebb40173744),  QWord($cc420a6a101d0515), QWord($9fa946824a12232d),
    QWord($47939822dc96abf9), QWord($59787e2b93bc56f7), QWord($57eb4edb3c55b65a), QWord($ede622920b6b23f1),
    QWord($e95fab368e45eced), QWord($11dbcb0218ebb414), QWord($d652bdc29f26a119), QWord($4be76d3346f0495f),
    QWord($6f70a4400c562ddb), QWord($cb4ccd500f6bb952), QWord($7e2000a41346a7a7), QWord($8ed400668c0c28c8),
    QWord($728900802f0f32fa), QWord($4f2b40a03ad2ffb9), QWord($e2f610c84987bfa8), QWord($dd9ca7d2df4d7c9),
    QWord($91503d1c79720dbb), QWord($75a44c6397ce912a), QWord($c986afbe3ee11aba), QWord($fbe85badce996168),
    QWord($fae27299423fb9c3), QWord($dccd879fc967d41a), QWord($5400e987bbc1c920), QWord($290123e9aab23b68),
    QWord($f9a0b6720aaf6521), QWord($f808e40e8d5b3e69), QWord($b60b1d1230b20e04), QWord($b1c6f22b5e6f48c2),
    QWord($1e38aeb6360b1af3), QWord($25c6da63c38de1b0), QWord($579c487e5a38ad0e), QWord($2d835a9df0c6d851),
    QWord($f8e431456cf88e65), QWord($1b8e9ecb641b58ff), QWord($e272467e3d222f3f), QWord($5b0ed81dcc6abb0f),
    QWord($98e947129fc2b4e9), QWord($3f2398d747b36224), QWord($8eec7f0d19a03aad), QWord($1953cf68300424ac),
    QWord($5fa8c3423c052dd7), QWord($3792f412cb06794d), QWord($e2bbd88bbee40bd0), QWord($5b6aceaeae9d0ec4),
    QWord($f245825a5a445275), QWord($eed6e2f0f0d56712), QWord($55464dd69685606b), QWord($aa97e14c3c26b886),
    QWord($d53dd99f4b3066a8), QWord($e546a8038efe4029), QWord($de98520472bdd033), QWord($963e66858f6d4440),
    QWord($dde7001379a44aa8), QWord($5560c018580d5d52), QWord($aab8f01e6e10b4a6), QWord($cab3961304ca70e8),
    QWord($3d607b97c5fd0d22), QWord($8cb89a7db77c506a), QWord($77f3608e92adb242), QWord($55f038b237591ed3),
    QWord($6b6c46dec52f6688), QWord($2323ac4b3b3da015), QWord($abec975e0a0d081a), QWord($96e7bd358c904a21),
    QWord($7e50d64177da2e54), QWord($dde50bd1d5d0b9e9), QWord($955e4ec64b44e864), QWord($bd5af13bef0b113e),
    QWord($ecb1ad8aeacdd58e), QWord($67de18eda5814af2), QWord($80eacf948770ced7), QWord($a1258379a94d028d),
    QWord($96ee45813a04330),  QWord($8bca9d6e188853fc), QWord($775ea264cf55347d), QWord($95364afe032a819d),
    QWord($3a83ddbd83f52204), QWord($c4926a9672793542), QWord($75b7053c0f178293), QWord($5324c68b12dd6338),
    QWord($d3f6fc16ebca5e03), QWord($88f4bb1ca6bcf584), QWord($2b31e9e3d06c32e5), QWord($3aff322e62439fcf),
    QWord($9befeb9fad487c2),  QWord($4c2ebe687989a9b3), QWord($f9d37014bf60a10),  QWord($538484c19ef38c94),
    QWord($2865a5f206b06fb9), QWord($f93f87b7442e45d3), QWord($f78f69a51539d748), QWord($b573440e5a884d1b),
    QWord($31680a88f8953030), QWord($fdc20d2b36ba7c3d), QWord($3d32907604691b4c), QWord($a63f9a49c2c1b10f),
    QWord($fcf80dc33721d53),  QWord($d3c36113404ea4a8), QWord($645a1cac083126e9), QWord($3d70a3d70a3d70a3),
    QWord($cccccccccccccccc), QWord($0),                QWord($0),                QWord($0),
    QWord($0),                QWord($0),                QWord($0),                QWord($0),
    QWord($0),                QWord($0),                QWord($0),                QWord($0),
    QWord($0),                QWord($0),                QWord($0),                QWord($0),
    QWord($0),                QWord($0),                QWord($0),                QWord($0),
    QWord($0),                QWord($0),                QWord($0),                QWord($0),
    QWord($0),                QWord($0),                QWord($0),                QWord($0),
    QWord($0),                QWord($4000000000000000), QWord($5000000000000000), QWord($a400000000000000),
    QWord($4d00000000000000), QWord($f020000000000000), QWord($6c28000000000000), QWord($c732000000000000),
    QWord($3c7f400000000000), QWord($4b9f100000000000), QWord($1e86d40000000000), QWord($1314448000000000),
    QWord($17d955a000000000), QWord($5dcfab0800000000), QWord($5aa1cae500000000), QWord($f14a3d9e40000000),
    QWord($6d9ccd05d0000000), QWord($e4820023a2000000), QWord($dda2802c8a800000), QWord($d50b2037ad200000),
    QWord($4526f422cc340000), QWord($9670b12b7f410000), QWord($3c0cdd765f114000), QWord($a5880a69fb6ac800),
    QWord($8eea0d047a457a00), QWord($72a4904598d6d880), QWord($47a6da2b7f864750), QWord($999090b65f67d924),
    QWord($fff4b4e3f741cf6d), QWord($bff8f10e7a8921a4), QWord($aff72d52192b6a0d), QWord($9bf4f8a69f764490),
    QWord($2f236d04753d5b4),  QWord($1d762422c946590),  QWord($424d3ad2b7b97ef5), QWord($d2e0898765a7deb2),
    QWord($63cc55f49f88eb2f), QWord($3cbf6b71c76b25fb), QWord($8bef464e3945ef7a), QWord($97758bf0e3cbb5ac),
    QWord($3d52eeed1cbea317), QWord($4ca7aaa863ee4bdd), QWord($8fe8caa93e74ef6a), QWord($b3e2fd538e122b44),
    QWord($60dbbca87196b616), QWord($bc8955e946fe31cd), QWord($6babab6398bdbe41), QWord($c696963c7eed2dd1),
    QWord($fc1e1de5cf543ca2), QWord($3b25a55f43294bcb), QWord($49ef0eb713f39ebe), QWord($6e3569326c784337),
    QWord($49c2c37f07965404), QWord($dc33745ec97be906), QWord($69a028bb3ded71a3), QWord($c40832ea0d68ce0c),
    QWord($f50a3fa490c30190), QWord($792667c6da79e0fa), QWord($577001b891185938), QWord($ed4c0226b55e6f86),
    QWord($544f8158315b05b4), QWord($696361ae3db1c721), QWord($3bc3a19cd1e38e9),  QWord($4ab48a04065c723),
    QWord($62eb0d64283f9c76), QWord($3ba5d0bd324f8394), QWord($ca8f44ec7ee36479), QWord($7e998b13cf4e1ecb),
    QWord($9e3fedd8c321a67e), QWord($c5cfe94ef3ea101e), QWord($bba1f1d158724a12), QWord($2a8a6e45ae8edc97),
    QWord($f52d09d71a3293bd), QWord($593c2626705f9c56), QWord($6f8b2fb00c77836c), QWord($b6dfb9c0f956447),
    QWord($4724bd4189bd5eac), QWord($58edec91ec2cb657), QWord($2f2967b66737e3ed), QWord($bd79e0d20082ee74),
    QWord($ecd8590680a3aa11), QWord($e80e6f4820cc9495), QWord($3109058d147fdcdd), QWord($bd4b46f0599fd415),
    QWord($6c9e18ac7007c91a), QWord($3e2cf6bc604ddb0),  QWord($84db8346b786151c), QWord($e612641865679a63),
    QWord($4fcb7e8f3f60c07e), QWord($e3be5e330f38f09d), QWord($5cadf5bfd3072cc5), QWord($73d9732fc7c8f7f6),
    QWord($2867e7fddcdd9afa), QWord($b281e1fd541501b8), QWord($1f225a7ca91a4226), QWord($3375788de9b06958),
    QWord($52d6b1641c83ae),   QWord($c0678c5dbd23a49a), QWord($f840b7ba963646e0), QWord($b650e5a93bc3d898),
    QWord($a3e51f138ab4cebe), QWord($c66f336c36b10137), QWord($b80b0047445d4184), QWord($a60dc059157491e5),
    QWord($87c89837ad68db2f), QWord($29babe4598c311fb), QWord($f4296dd6fef3d67a), QWord($1899e4a65f58660c),
    QWord($5ec05dcff72e7f8f), QWord($76707543f4fa1f73), QWord($6a06494a791c53a8), QWord($487db9d17636892),
    QWord($45a9d2845d3c42b6), QWord($b8a2392ba45a9b2),  QWord($8e6cac7768d7141e), QWord($3207d795430cd926),
    QWord($7f44e6bd49e807b8), QWord($5f16206c9c6209a6), QWord($36dba887c37a8c0f), QWord($c2494954da2c9789),
    QWord($f2db9baa10b7bd6c), QWord($6f92829494e5acc7), QWord($cb772339ba1f17f9), QWord($ff2a760414536efb),
    QWord($fef5138519684aba), QWord($7eb258665fc25d69), QWord($ef2f773ffbd97a61), QWord($aafb550ffacfd8fa),
    QWord($95ba2a53f983cf38), QWord($dd945a747bf26183), QWord($94f971119aeef9e4), QWord($7a37cd5601aab85d),
    QWord($ac62e055c10ab33a), QWord($577b986b314d6009), QWord($ed5a7e85fda0b80b), QWord($14588f13be847307),
    QWord($596eb2d8ae258fc8), QWord($6fca5f8ed9aef3bb), QWord($25de7bb9480d5854), QWord($af561aa79a10ae6a),
    QWord($1b2ba1518094da04), QWord($90fb44d2f05d0842), QWord($353a1607ac744a53), QWord($42889b8997915ce8),
    QWord($69956135febada11), QWord($43fab9837e699095), QWord($94f967e45e03f4bb), QWord($1d1be0eebac278f5),
    QWord($6462d92a69731732), QWord($7d7b8f7503cfdcfe), QWord($5cda735244c3d43e), QWord($3a0888136afa64a7),
    QWord($88aaa1845b8fdd0),  QWord($8aad549e57273d45), QWord($36ac54e2f678864b), QWord($84576a1bb416a7dd),
    QWord($656d44a2a11c51d5), QWord($9f644ae5a4b1b325), QWord($873d5d9f0dde1fee), QWord($a90cb506d155a7ea),
    QWord($9a7f12442d588f2),  QWord($c11ed6d538aeb2f),  QWord($8f1668c8a86da5fa), QWord($f96e017d694487bc),
    QWord($37c981dcc395a9ac), QWord($85bbe253f47b1417), QWord($93956d7478ccec8e), QWord($387ac8d1970027b2),
    QWord($6997b05fcc0319e),  QWord($441fece3bdf81f03), QWord($d527e81cad7626c3), QWord($8a71e223d8d3b074),
    QWord($f6872d5667844e49), QWord($b428f8ac016561db), QWord($e13336d701beba52), QWord($ecc0024661173473),
    QWord($27f002d7f95d0190), QWord($31ec038df7b441f4), QWord($7e67047175a15271), QWord($f0062c6e984d386),
    QWord($52c07b78a3e60868), QWord($a7709a56ccdf8a82), QWord($88a66076400bb691), QWord($6acff893d00ea435),
    QWord($583f6b8c4124d43),  QWord($c3727a337a8b704a), QWord($744f18c0592e4c5c), QWord($1162def06f79df73),
    QWord($8addcb5645ac2ba8), QWord($6d953e2bd7173692), QWord($c8fa8db6ccdd0437), QWord($1d9c9892400a22a2),
    QWord($2503beb6d00cab4b), QWord($2e44ae64840fd61d), QWord($5ceaecfed289e5d2), QWord($7425a83e872c5f47),
    QWord($d12f124e28f77719), QWord($82bd6b70d99aaa6f), QWord($636cc64d1001550b), QWord($3c47f7e05401aa4e),
    QWord($65acfaec34810a71), QWord($7f1839a741a14d0d), QWord($1ede48111209a050), QWord($934aed0aab460432),
    QWord($f81da84d5617853f), QWord($36251260ab9d668e), QWord($c1d72b7c6b426019), QWord($b24cf65b8612f81f),
    QWord($dee033f26797b627), QWord($169840ef017da3b1), QWord($8e1f289560ee864e), QWord($f1a6f2bab92a27e2),
    QWord($ae10af696774b1db), QWord($acca6da1e0a8ef29), QWord($17fd090a58d32af3), QWord($ddfc4b4cef07f5b0),
    QWord($4abdaf101564f98e), QWord($9d6d1ad41abe37f1), QWord($84c86189216dc5ed), QWord($32fd3cf5b4e49bb4),
    QWord($3fbc8c33221dc2a1), QWord($fabaf3feaa5334a),  QWord($29cb4d87f2a7400e), QWord($743e20e9ef511012),
    QWord($914da9246b255416), QWord($1ad089b6c2f7548e), QWord($a184ac2473b529b1), QWord($c9e5d72d90a2741e),
    QWord($7e2fa67c7a658892), QWord($ddbb901b98feeab7), QWord($552a74227f3ea565), QWord($d53a88958f87275f),
    QWord($8a892abaf368f137), QWord($2d2b7569b0432d85), QWord($9c3b29620e29fc73), QWord($8349f3ba91b47b8f),
    QWord($241c70a936219a73), QWord($ed238cd383aa0110), QWord($f4363804324a40aa), QWord($b143c6053edcd0d5),
    QWord($dd94b7868e94050a), QWord($ca7cf2b4191c8326), QWord($fd1c2f611f63a3f0), QWord($bc633b39673c8cec),
    QWord($d5be0503e085d813), QWord($4b2d8644d8a74e18), QWord($ddf8e7d60ed1219e), QWord($cabb90e5c942b503),
    QWord($3d6a751f3b936243), QWord($cc512670a783ad4),  QWord($27fb2b80668b24c5), QWord($b1f9f660802dedf6),
    QWord($5e7873f8a0396973), QWord($db0b487b6423e1e8), QWord($91ce1a9a3d2cda62), QWord($7641a140cc7810fb),
    QWord($a9e904c87fcb0a9d), QWord($546345fa9fbdcd44), QWord($a97c177947ad4095), QWord($49ed8eabcccc485d),
    QWord($5c68f256bfff5a74), QWord($73832eec6fff3111), QWord($c831fd53c5ff7eab), QWord($ba3e7ca8b77f5e55),
    QWord($28ce1bd2e55f35eb), QWord($7980d163cf5b81b3), QWord($d7e105bcc332621f), QWord($8dd9472bf3fefaa7),
    QWord($b14f98f6f0feb951), QWord($6ed1bf9a569f33d3), QWord($a862f80ec4700c8),  QWord($cd27bb612758c0fa),
    QWord($8038d51cb897789c), QWord($e0470a63e6bd56c3), QWord($1858ccfce06cac74), QWord($f37801e0c43ebc8),
    QWord($d30560258f54e6ba), QWord($47c6b82ef32a2069), QWord($4cdc331d57fa5441), QWord($e0133fe4adf8e952),
    QWord($58180fddd97723a6), QWord($570f09eaa7ea7648));
var
  ProdLo, ProdHi, Mid, MsBit, Mantissa: QWord;
  Exponent: Int64;
  LzCount: Integer;
  Prod: TOWord;
begin
{$IFDEF CPU64}
  if (aPow10 >= -22) and (aPow10 <= 22) and (aMantissa <= 9007199254740991) then
    begin
      aValue := Double(aMantissa);
      if aPow10 < 0 then
        aValue /= TEN_POWER[-aPow10]
      else
        aValue *= TEN_POWER[aPow10];
      if aNeg then
        PQWord(@aValue)^ := QWord(aValue) or QWord(1) shl 63;
      exit(True);
    end;
{$ENDIF CPU64}
  if aMantissa = 0 then
    begin
      if aNeg then
        PQWord(@aValue)^ := QWord(1) shl 63
      else
        aValue := Double(0.0);
      exit(True);
    end;

  Exponent := SarInt64((152170 + 65536) * aPow10, 16) + 1024 + 63;
  LzCount := Pred(BitSizeOf(QWord)) - BsrQWord(aMantissa);
  aMantissa := aMantissa shl LzCount;

  UMul64Full(aMantissa, EL_MANTIS_64[aPow10], Prod);
  ProdLo := Prod.Lo;
  ProdHi := Prod.Hi;

  if (ProdHi and $1FF = $1FF) and (ProdLo + aMantissa < ProdLo) then
    begin
      UMul64Full(aMantissa, EL_MANTIS_128[aPow10], Prod);
      Mid := ProdLo + Prod.Hi;
      ProdHi += Ord(Mid < ProdLo);
      if (Succ(Mid) = 0) and (ProdHi and $1FF = $1FF) and (Prod.Lo + aMantissa < Prod.Lo) then
        exit(False);
      ProdLo := Mid;
    end;

  MsBit := ProdHi shr 63;
  Mantissa := ProdHi shr (MsBit + 9);
  LzCount += Ord(MsBit xor 1);

  if (ProdLo = 0) and (ProdHi and $1FF = 0) and (Mantissa and 3 = 1) then
    exit(False);

  Mantissa := (Mantissa + Mantissa and 1) shr 1;

  if Mantissa >= QWord(1) shl 53 then
    begin
      Mantissa := QWord(1) shl 52;
      Dec(LzCount);
    end;
  Mantissa := Mantissa and not(QWord(1) shl 52);

  Exponent -= LzCount;
  if (Exponent < 1) or (Exponent > 2046) then
    exit(False);

  PQWord(@aValue)^ := Mantissa or QWord(Exponent shl 52) or QWord(aNeg) shl 63;
  Result := True;
end;

function TryPChar2DoubleFallBack(p: PAnsiChar; out aValue: Double): Boolean;
var
  Code: Integer;
begin
  try
    Val(p, aValue, Code);
    Result := (Code = 0) and (QWord(aValue) and INF_EXP <> INF_EXP);
  except
    Result := False;
  end;
end;

{ TryPChar2DoubleFast is a relaxed parser, it expects a valid null-terminated
  JSON number representation to be passed as the P parameter }
function TryPChar2DoubleFast(p: PAnsiChar; out aValue: Double): Boolean;
var
  Man: QWord;
  Pow10, PowVal: Int64;
  DigCount: Integer;
  pOld, pDigStart, pTemp: PAnsiChar;
  IsNeg, PowIsNeg: Boolean;
const
  Digits: array['0'..'9'] of DWord = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
begin
  if p^ = #0 then
    exit(False);
  pOld := p;
  IsNeg := False;
  if p^ = '-' then
    begin
      Inc(p);
      IsNeg := True;
    end;
  if p^ = '0' then
    begin
      Man := 0;
      Inc(p);
      pDigStart := p;
    end
  else
    begin
      pDigStart := p;
      Man := Digits[p^];
      Inc(p);
      while p^ in ['0'..'9'] do
        begin
          Man := Man * 10 + Digits[p^];
          Inc(p);
        end;
    end;
  Pow10 := 0;
  if p^ = '.' then
    begin
      Inc(p);
      pTemp := p;
      while p^ in ['0'..'9'] do
        begin
          Man := Man * 10 + Digits[p^];
          Inc(p);
        end;
      Pow10 := -Int64(p - pTemp);
      DigCount := p - pDigStart - 1;
    end
  else
    DigCount := p - pDigStart;
  if p^ in ['e', 'E'] then
    begin
      PowIsNeg := False;
      Inc(p);
      if p^ = '-' then
        begin
          PowIsNeg := True;
          Inc(p);
        end
      else
        if p^ = '+' then
          Inc(p);
      PowVal := Integer(Digits[p^]);
      Inc(p);
      while p^ in ['0'..'9'] do
        begin
          if PowVal < $100000000 then
            PowVal := PowVal * 10 + Integer(Digits[p^]);
          Inc(p);
        end;
      if PowIsNeg then
        Pow10 -= PowVal
      else
        Pow10 += PowVal;
    end;
  if DigCount >= 19 then
    begin
      pTemp := pDigStart;
      while pTemp^ in ['0', '.'] do
        Inc(pTemp);
      DigCount -= pTemp - pDigStart;
      if DigCount >= 19 then
        exit(TryPChar2DoubleFallBack(pOld, aValue));
    end;
  if (Pow10 < ELDBL_LOWEST_POWER) or (Pow10 > ELDBL_HIGHEST_POWER) then
    exit(TryPChar2DoubleFallBack(pOld, aValue));
  if TryBuildDoubleEiselLemire(Man, Pow10, IsNeg, aValue) then
    exit(True);
  Result := TryPChar2DoubleFallBack(pOld, aValue);
end;

function TryPChar2DblFallBack(p: PAnsiChar; out aValue: Double): Boolean;
var
  Code: Integer;
begin
  try
    Val(p, aValue, Code);
    Result := Code = 0;
  except
    on e: EOverflow do  //todo: ???
      begin
        PQWord(@aValue)^ := INF_EXP;
        Result := True;
      end;
    on e: Exception do
      Result := False;
  end;
end;

{ TryPChar2Double }
function TryPChar2Double(p: PAnsiChar; out aValue: Double): Boolean;
var
  Man: QWord;
  Pow10, PowVal: Int64;
  DigCount: Integer;
  pOld, pDigStart, pTemp: PAnsiChar;
  IsNeg, PowIsNeg: Boolean;
const
  Digits: array['0'..'9'] of DWord = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
begin
  if p^ = #0 then
    exit(False);
  pOld := p;
  IsNeg := False;
  if p^ = '-' then
    begin
      Inc(p);
      IsNeg := True;
    end;
  if p^ = '0' then
    begin
      Inc(p);
      if p^ in ['0'..'9'] then exit(False);
      Man := 0;
      pDigStart := p;
    end
  else
    begin
      if not(p^ in ['0'..'9']) then exit(False);
      pDigStart := p;
      Man := Digits[p^];
      Inc(p);
      while p^ in ['0'..'9'] do
        begin
          Man := Man * 10 + Digits[p^];
          Inc(p);
        end;
    end;
  Pow10 := 0;
  if p^ = '.' then
    begin
      Inc(p);
      if not(p^ in ['0'..'9']) then exit(False);
      pTemp := p;
      while p^ in ['0'..'9'] do
        begin
          Man := Man * 10 + Digits[p^];
          Inc(p);
        end;
      Pow10 := -Int64(p - pTemp);
      DigCount := p - pDigStart - 1;
    end
  else
    DigCount := p - pDigStart;
  if p^ in ['e', 'E'] then
    begin
      PowIsNeg := False;
      Inc(p);
      if p^ = '-' then
        begin
          PowIsNeg := True;
          Inc(p);
        end
      else
        if p^ = '+' then
          Inc(p);
      if not(p^ in ['0'..'9']) then exit(False);
      PowVal := Integer(Digits[p^]);
      Inc(p);
      while p^ in ['0'..'9'] do
        begin
          if PowVal < $100000000 then
            PowVal := PowVal * 10 + Integer(Digits[p^]);
          Inc(p);
        end;
      if PowIsNeg then
        Pow10 -= PowVal
      else
        Pow10 += PowVal;
    end;
  ////////////////////////////
  if p^ <> #0 then exit(False);
  ////////////////////////////

  if DigCount >= 19 then
    begin
      pTemp := pDigStart;
      while pTemp^ in ['0', '.'] do
        Inc(pTemp);
      DigCount -= pTemp - pDigStart;
      if DigCount >= 19 then
        exit(TryPChar2DblFallBack(pOld, aValue));
    end;
  if (Pow10 < ELDBL_LOWEST_POWER) or (Pow10 > ELDBL_HIGHEST_POWER) then
    exit(TryPChar2DblFallBack(pOld, aValue));
  if TryBuildDoubleEiselLemire(Man, Pow10, IsNeg, aValue) then
    exit(True);
  Result := TryPChar2DblFallBack(pOld, aValue);
end;
{$POP}

function TryStr2Double(const s: string; out aValue: Double): Boolean;
begin
  Result := TryPChar2Double(PAnsiChar(s), aValue);
end;

{$PUSH}{$J-}{$WARN 2005 OFF}
const
  StateTransitions: array[GO..N3, Space..Etc] of Integer = (
{
  The state transition table takes the current state and the current symbol,
  and returns either a new state or an action. An action is represented as a
  number > 30.

             white                                      1-9                                   ABCDF  etc
         space |  {  }  [  ]  :  ,  "  \  /  +  -  .  0  |  a  b  c  d  e  f  l  n  r  s  t  u  |  E  | }
{start  GO}(GO,GO,34,__,35,__,__,__,ST,__,__,__,MI,__,ZE,IR,__,__,__,__,__,F1,__,N1,__,__,T1,__,__,__,__),
{ok     OK}(OK,OK,__,32,__,33,__,37,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{object OB}(OB,OB,__,31,__,__,__,__,ST,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{key    KE}(KE,KE,__,__,__,__,__,__,ST,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{colon  CO}(CO,CO,__,__,__,__,38,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{value  VA}(VA,VA,34,__,35,__,__,__,ST,__,__,__,MI,__,ZE,IR,__,__,__,__,__,F1,__,N1,__,__,T1,__,__,__,__),
{array  AR}(AR,AR,34,__,35,33,__,__,ST,__,__,__,MI,__,ZE,IR,__,__,__,__,__,F1,__,N1,__,__,T1,__,__,__,__),
{string ST}(ST,__,ST,ST,ST,ST,ST,ST,36,ES,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST,ST),
{escape ES}(__,__,__,__,__,__,__,__,ST,ST,ST,__,__,__,__,__,__,ST,__,__,__,ST,__,ST,ST,__,ST,U1,__,__,__),
{u1     U1}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,U2,U2,U2,U2,U2,U2,U2,U2,__,__,__,__,__,__,U2,U2,__),
{u2     U2}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,U3,U3,U3,U3,U3,U3,U3,U3,__,__,__,__,__,__,U3,U3,__),
{u3     U3}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,U4,U4,U4,U4,U4,U4,U4,U4,__,__,__,__,__,__,U4,U4,__),
{u4     U4}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,ST,ST,ST,ST,ST,ST,ST,ST,__,__,__,__,__,__,ST,ST,__),
{minus  MI}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,ZE,IR,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{zero   ZE}(40,40,__,32,__,33,__,39,__,__,__,__,__,FR,__,__,__,__,__,__,E1,__,__,__,__,__,__,__,__,E1,__),
{int    IR}(40,40,__,32,__,33,__,39,__,__,__,__,__,FR,IR,IR,__,__,__,__,E1,__,__,__,__,__,__,__,__,E1,__),
{frac   FR}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,FS,FS,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{fracs  FS}(40,40,__,32,__,33,__,39,__,__,__,__,__,__,FS,FS,__,__,__,__,E1,__,__,__,__,__,__,__,__,E1,__),
{e      E1}(__,__,__,__,__,__,__,__,__,__,__,E2,E2,__,E3,E3,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{ex     E2}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,E3,E3,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{exp    E3}(40,40,__,32,__,33,__,39,__,__,__,__,__,__,E3,E3,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{tr     T1}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,T2,__,__,__,__,__,__),
{tru    T2}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,T3,__,__,__),
{true   T3}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,41,__,__,__,__,__,__,__,__,__,__),
{fa     F1}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,F2,__,__,__,__,__,__,__,__,__,__,__,__,__,__),
{fal    F2}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,F3,__,__,__,__,__,__,__,__),
{fals   F3}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,F4,__,__,__,__,__),
{false  F4}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,42,__,__,__,__,__,__,__,__,__,__),
{nu     N1}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,N2,__,__,__),
{nul    N2}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,N3,__,__,__,__,__,__,__,__),
{null   N3}(__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,__,43,__,__,__,__,__,__,__,__)
  );
{$POP}

{$PUSH}{$WARN 5089 OFF}
function DoParseStr(Buf: PAnsiChar; Size: SizeInt; aNode: TJsonNode; const aStack: TOpenArray): Boolean;
var
  Stack: PParseNode;
  I: SizeInt;
  NextState, NextClass, StackHigh: Integer;
  State: Integer = GO;
  sTop: Integer = 1;
  sb: TJsonNode.TStrBuilder;
  KeyValue: string = '';
  function Number: Double; inline;
  begin
    if not TryPChar2DoubleFast(sb.ToPChar, Result) then
      Abort;
  end;
begin
  Stack := aStack.Data;
  StackHigh := Pred(aStack.Size);
  Stack[0].Create(nil, pmNone);
  Stack[1].Create(aNode, pmNone);
  sb := TJsonNode.TStrBuilder.Create(TJsonNode.S_BUILD_INIT_SIZE);
  for I := 0 to Pred(Size) do begin
    if Buf[I] < #128 then begin
      NextClass := SymClassTable[Ord(Buf[I])];
      if NextClass = __ then exit(False);
    end else
      NextClass := Etc;
    NextState := StateTransitions[State, NextClass];
    if NextState = __ then exit(False);
    if NextState < 31 then begin
      if DWord(NextState - ST) < DWord(14) then
        sb.Append(Buf[I]); /////////////////////
      State := NextState;
    end else
      case NextState of
        31: //end object - state = object
          if Stack[sTop].Mode = pmKey then begin
            Dec(sTop);
            State := OK;
          end else exit(False);
        32: //end object
          if Stack[sTop].Mode = pmObject then begin
            if Integer(1 shl State) and NUM_STATES <> 0 then
              Stack[sTop].Node.Add(KeyValue, Number);
            Dec(sTop);
            State := OK;
          end else exit(False);
        33: //end array
          if Stack[sTop].Mode = pmArray then begin
            if Integer(1 shl State) and NUM_STATES <> 0 then
              Stack[sTop].Node.Add(Number);
            Dec(sTop);
            State := OK;
          end else exit(False);
        34: //begin object
          if sTop < StackHigh then begin
            case Stack[sTop].Mode of
              pmNone: begin
                  Stack[sTop].Node.AsObject;
                  Stack[sTop].Mode := pmKey;
                end;
              pmArray: begin
                  Stack[sTop+1].Create(Stack[sTop].Node.AddNode(jvkObject), pmKey);
                  Inc(sTop);
                end;
              pmObject: begin
                  Stack[sTop+1].Create(Stack[sTop].Node.AddNode(KeyValue, jvkObject), pmKey);
                  Inc(sTop);
                end;
            else
              exit(False);
            end;
            State := OB;
          end else exit(False);
        35: //begin array
          if sTop < StackHigh then begin
            case Stack[sTop].Mode of
              pmNone: begin
                  Stack[sTop].Node.AsArray;
                  Stack[sTop].Mode := pmArray;
                end;
              pmArray: begin
                  Stack[sTop+1].Create(Stack[sTop].Node.AddNode(jvkArray), pmArray);
                  Inc(sTop);
                end;
              pmObject: begin
                  Stack[sTop+1].Create(Stack[sTop].Node.AddNode(KeyValue, jvkArray), pmArray);
                  Inc(sTop);
                end;
            else
              exit(False);
            end;
            State := AR;
          end else exit(False);
        36: //string value
          begin
            sb.Append(Buf[I]);
            case Stack[sTop].Mode of
              pmKey: begin
                  KeyValue := sb.ToDecodeString;
                  State := CO;
                end;
              pmArray: begin
                  Stack[sTop].Node.Add(sb.ToDecodeString);
                  State := OK;
                end;
              pmObject: begin
                  Stack[sTop].Node.Add(KeyValue, sb.ToDecodeString);
                  State := OK;
                end
            else
              Stack[sTop].Node.AsString := sb.ToDecodeString;
              Dec(sTop);
              State := OK;
            end;
          end;
        37: //OK - comma
          case Stack[sTop].Mode of
            pmObject: begin
                Stack[sTop].Mode := pmKey;
                State := KE;
              end;
            pmArray: State := VA;
          else
            exit(False);
          end;
        38: //colon
          if Stack[sTop].Mode = pmKey then begin
            Stack[sTop].Mode := pmObject;
            State := VA;
          end else exit(False);
        39: //end Number - comma
          case Stack[sTop].Mode of
            pmArray: begin
                Stack[sTop].Node.Add(Number);
                State := VA;
              end;
            pmObject: begin
                Stack[sTop].Node.Add(KeyValue, Number);
                Stack[sTop].Mode := pmKey;
                State := KE;
              end;
          else
            exit(False);
          end;
        40: //end Number - white space
          begin
            case Stack[sTop].Mode of
              pmArray:  Stack[sTop].Node.Add(Number);
              pmObject: Stack[sTop].Node.Add(KeyValue, Number);
            else
              Stack[sTop].Node.AsNumber := Number;
              Dec(sTop);
            end;
            State := OK;
          end;
        41: //true literal
          begin
            case Stack[sTop].Mode of
              pmArray:  Stack[sTop].Node.Add(True);
              pmObject: Stack[sTop].Node.Add(KeyValue, True);
            else
              Stack[sTop].Node.AsBoolean := True;
              Dec(sTop);
            end;
            State := OK;
          end;
        42: //false literal
          begin
            case Stack[sTop].Mode of
              pmArray:  Stack[sTop].Node.Add(False);
              pmObject: Stack[sTop].Node.Add(KeyValue, False);
            else
              Stack[sTop].Node.AsBoolean := False;
              Dec(sTop);
            end;
            State := OK;
          end;
        43: //null literal
          begin
            case Stack[sTop].Mode of
              pmArray:  Stack[sTop].Node.AddNull;
              pmObject: Stack[sTop].Node.AddNull(KeyValue);
            else
              Stack[sTop].Node.AsNull;
              Dec(sTop);
            end;
            State := OK;
          end;
      else
        exit(False);
      end;
  end;
  if Integer(1 shl State) and NUM_STATES <> 0 then begin
    if Stack[sTop].Mode <> pmNone then exit(False);
    Stack[sTop].Node.AsNumber := Number;
    State := OK;
    Dec(sTop);
  end;
  Result := (State = OK) and (sTop = 0) and (Stack[0].Node = nil) and (Stack[0].Mode = pmNone);
end;
{$POP}

const
  AN = Integer(7); //Array Next

{ TJsonWriter }

procedure TJsonWriter.ValueAdding;
begin
  case FStack.PeekItem^ of
    VA: FStack.PeekItem^ := OB;
    AR: FStack.PeekItem^ := AN;
    AN: FStream.WriteBuffer(chComma, SizeOf(chComma));
  else
  end;
end;

procedure TJsonWriter.PairAdding;
begin
  case FStack.PeekItem^ of
    OB: FStream.WriteBuffer(chComma, SizeOf(chComma));
    KE: FStack.PeekItem^ := OB;
  else
  end;
end;

class function TJsonWriter.New(aStream: TStream): TJsonWriter;
begin
  Result := TJsonWriter.Create(aStream);
end;

class function TJsonWriter.WriteJson(aStream: TStream; aNode: TJsonNode): SizeInt;
var
  Writer: TJsonWriter = nil;
  p: TJsonNode.TPair;
  procedure WriteNode(aInst: TJsonNode);
  var
    I: SizeInt;
  begin
    case aInst.Kind of
      jvkNull:   Writer.AddNull;
      jvkFalse:  Writer.AddFalse;
      jvkTrue:   Writer.AddTrue;
      jvkNumber: Writer.Add(aInst.FValue.Num);
      jvkString: Writer.Add(aInst.FString);
      jvkArray:
        begin
          Writer.BeginArray;
          if aInst.FArray <> nil then
            for I := 0 to Pred(aInst.FArray^.Count) do
              WriteNode(aInst.FArray^.UncMutable[I]^);
          Writer.EndArray;
        end;
      jvkObject:
        begin
          Writer.BeginObject;
          if aInst.FObject <> nil then
            for I := 0 to Pred(aInst.FObject^.Count) do
              begin
                p := aInst.FObject^.Mutable[I]^;
                Writer.AddName(p.Key);
                WriteNode(p.Value);
              end;
          Writer.EndObject;
        end;
    else
    end;
  end;
begin
  Result := aStream.Position;
  Writer := TJsonWriter.Create(aStream);
  try
    WriteNode(aNode);
  finally
    Writer.Free;
  end;
  Result := aStream.Position - Result;
end;

constructor TJsonWriter.Create(aStream: TStream);
begin
  FStream := TWriteBufStream.Create(aStream, TJsonNode.RW_BUF_SIZE);
  FsBuilder := TJsonNode.TStrBuilder.Create(TJsonNode.S_BUILD_INIT_SIZE);
  FStack.Push(OK);
end;

destructor TJsonWriter.Destroy;
begin
  FStream.Free;
  inherited;
end;

function TJsonWriter.AddNull: TJsonWriter;
begin
  ValueAdding;
  FStream.WriteBuffer(JS_NULL[1], System.Length(JS_NULL));
  Result := Self;
end;

function TJsonWriter.AddFalse: TJsonWriter;
begin
  ValueAdding;
  FStream.WriteBuffer(JS_FALSE[1], System.Length(JS_FALSE));
  Result := Self;
end;

function TJsonWriter.AddTrue: TJsonWriter;
begin
  ValueAdding;
  FStream.WriteBuffer(JS_TRUE[1], System.Length(JS_TRUE));
  Result := Self;
end;

function TJsonWriter.Add(aValue: Double): TJsonWriter;
var
  num: shortstring;
begin
  ValueAdding;
  Double2Str(aValue, num);
  FStream.WriteBuffer(num[1], System.Length(num));
  Result := Self;
end;

function TJsonWriter.Add(const s: string): TJsonWriter;
begin
  ValueAdding;
  FsBuilder.AppendEncode(s);
  FsBuilder.SaveToStream(FStream);
  Result := Self;
end;

function TJsonWriter.Add(aValue: TJsonNode): TJsonWriter;
begin
  Result := AddJson(aValue.AsJson);
end;

function TJsonWriter.AddJson(const aJson: string): TJsonWriter;
begin
  ValueAdding;
  FStream.WriteBuffer(Pointer(aJson)^, System.Length(aJson));
  Result := Self;
end;

function TJsonWriter.AddName(const aName: string): TJsonWriter;
begin
  case FStack.PeekItem^ of
    OB: FStream.WriteBuffer(chComma, SizeOf(chComma));
    KE: FStack.PeekItem^ := VA;
  else
  end;
  FsBuilder.AppendEncode(aName);
  FsBuilder.SaveToStream(FStream);
  FStream.WriteBuffer(chColon, SizeOf(chColon));
  Result := Self;
end;

function TJsonWriter.AddNull(const aName: string): TJsonWriter;
begin
  PairAdding;
  FsBuilder.AppendEncode(aName);
  FsBuilder.SaveToStream(FStream);
  FStream.WriteBuffer(chColon, SizeOf(chColon));
  FStream.WriteBuffer(JS_NULL[1], System.Length(JS_NULL));
  Result := Self;
end;

function TJsonWriter.AddFalse(const aName: string): TJsonWriter;
begin
  PairAdding;
  FsBuilder.AppendEncode(aName);
  FsBuilder.SaveToStream(FStream);
  FStream.WriteBuffer(chColon, SizeOf(chColon));
  FStream.WriteBuffer(JS_FALSE[1], System.Length(JS_FALSE));
  Result := Self;
end;

function TJsonWriter.AddTrue(const aName: string): TJsonWriter;
begin
  PairAdding;
  FsBuilder.AppendEncode(aName);
  FsBuilder.SaveToStream(FStream);
  FStream.WriteBuffer(chColon, SizeOf(chColon));
  FStream.WriteBuffer(JS_TRUE[1], System.Length(JS_TRUE));
  Result := Self;
end;

function TJsonWriter.Add(const aName: string; aValue: Double): TJsonWriter;
var
  num: shortstring;
begin
  PairAdding;
  Double2Str(aValue, num);
  FsBuilder.AppendEncode(aName);
  FsBuilder.SaveToStream(FStream);
  FStream.WriteBuffer(chColon, SizeOf(chColon));
  FStream.WriteBuffer(num[1], System.Length(num));
  Result := Self;
end;

function TJsonWriter.Add(const aName, aValue: string): TJsonWriter;
begin
  PairAdding;
  FsBuilder.AppendEncode(aName);
  FsBuilder.SaveToStream(FStream);
  FStream.WriteBuffer(chColon, SizeOf(chColon));
  FsBuilder.AppendEncode(aValue);
  FsBuilder.SaveToStream(FStream);
  Result := Self;
end;

function TJsonWriter.Add(const aName: string; aValue: TJsonNode): TJsonWriter;
begin
  Result := AddJson(aName, aValue.AsJson);
end;

function TJsonWriter.AddJson(const aName, aJson: string): TJsonWriter;
begin
  PairAdding;
  FsBuilder.AppendEncode(aName);
  FsBuilder.SaveToStream(FStream);
  FStream.WriteBuffer(chColon, SizeOf(chColon));
  FStream.WriteBuffer(Pointer(aJson)^, System.Length(aJson));
  Result := Self;
end;

function TJsonWriter.BeginArray: TJsonWriter;
begin
  case FStack.PeekItem^ of
    VA: FStack.PeekItem^ := OB;
    AR: FStack.PeekItem^ := AN;
    AN: FStream.WriteBuffer(chComma, SizeOf(chComma));
  else
  end;
  FStream.WriteBuffer(chOpenSqrBr, SizeOf(chOpenSqrBr));
  FStack.Push(AR);
  Result := Self;
end;

function TJsonWriter.BeginObject: TJsonWriter;
begin
  case FStack.PeekItem^ of
    VA: FStack.PeekItem^ := OB;
    AR: FStack.PeekItem^ := AN;
    AN: FStream.WriteBuffer(chComma, SizeOf(chComma));
  else
  end;
  FStream.WriteBuffer(chOpenCurBr, SizeOf(chOpenCurBr));
  FStack.Push(KE);
  Result := Self;
end;

function TJsonWriter.EndArray: TJsonWriter;
begin
  FStream.WriteBuffer(chClosSqrBr, SizeOf(chClosSqrBr));
  FStack.Pop;
  Result := Self;
end;

function TJsonWriter.EndObject: TJsonWriter;
begin
  FStream.WriteBuffer(chClosCurBr, SizeOf(chClosCurBr));
  FStack.Pop;
  Result := Self;
end;

{ TJsonReader.TLevel }

constructor TJsonReader.TLevel.Create(aMode: TParseMode);
begin
  Mode := aMode;
  Path := '';
  CurrIndex := 0;
end;

constructor TJsonReader.TLevel.Create(aMode: TParseMode; aPath: string);
begin
  Mode := aMode;
  Path := aPath;
  CurrIndex := 0;
end;

constructor TJsonReader.TLevel.Create(aMode: TParseMode; aIndex: SizeInt);
begin
  Mode := aMode;
  Path := SizeUInt2Str(aIndex);
  CurrIndex := 0;
end;

{ TJsonReader }

function TJsonReader.GetIndex: SizeInt;
begin
  Result := FStack[Depth].CurrIndex;
end;

function TJsonReader.GetStructKind: TStructKind;
begin
  case FStack[Depth].Mode of
    pmArray:  Result := skArray;
    pmKey,
    pmObject: Result := skObject;
  else
    Result := skNone;
  end;
end;

function TJsonReader.GetParentKind: TStructKind;
begin
  if Depth > 0 then
    case FStack[Pred(Depth)].Mode of
      pmArray:         exit(skArray);
      pmKey, pmObject: exit(skObject);
    else
    end;
  Result := skNone;
end;

procedure TJsonReader.UpdateArray;
begin
  if FStack[Depth].Mode = pmArray then
    begin
      if ReadMode then
        FName := SizeUInt2Str(FStack[Depth].CurrIndex);
      Inc(FStack[Depth].CurrIndex);
    end;
end;

function TJsonReader.NullValue: Boolean;
begin
  if ReadMode then
    FValue.Clear;
  UpdateArray;
  FState := OK;
  FToken := tkNull;
  Result := True;
end;

function TJsonReader.FalseValue: Boolean;
begin
  if ReadMode then
    FValue := False;
  UpdateArray;
  FToken := tkFalse;
  FState := OK;
  Result := True;
end;

function TJsonReader.TrueValue: Boolean;
begin
  if ReadMode then
    FValue := True;
  UpdateArray;
  FState := OK;
  FToken := tkTrue;
  Result := True;
end;

function TJsonReader.NumValue: Boolean;
var
  d: Double;
begin
  if ReadMode then
    begin
      if not TryPChar2DoubleFast(FsBuilder.ToPChar, d) then
        exit(False);
      FValue := d;
    end;
  UpdateArray;
  FToken := tkNumber;
  Result := True;
end;

procedure TJsonReader.NameValue;
begin
  if ReadMode then
    FName := FsBuilder.ToDecodeString;
  FState := CO;
end;

function TJsonReader.CommaAfterNum: Boolean;
begin
  if not NumValue then
    exit(False);
  case FStack[Depth].Mode of
    pmArray: FState := VA;
    pmObject:
      begin
        FStack[Depth].Mode := pmKey;
        FState := KE;
      end;
  else
    exit(False);
  end;
  Result := True;
end;

function TJsonReader.StringValue: Boolean;
begin
  if ReadMode then
    FValue := FsBuilder.ToDecodeString;
  UpdateArray;
  FToken := tkString;
  FState := OK;
  Result := True;
end;

function TJsonReader.ArrayBegin: Boolean;
begin
  if Depth = FStackHigh then exit(False);
  case FStack[Depth].Mode of
    pmNone: FStack[Succ(Depth)] := TLevel.Create(pmArray);
    pmArray:
      if ReadMode then
        FStack[Succ(Depth)] := TLevel.Create(pmArray, FStack[Depth].CurrIndex)
      else
        FStack[Succ(Depth)] := TLevel.Create(pmArray);
    pmObject:
      if ReadMode then
        FStack[Succ(Depth)] := TLevel.Create(pmArray, FName)
      else
        FStack[Succ(Depth)] := TLevel.Create(pmArray);
  else
    exit(False);
  end;
  Inc(FStackTop);
  FToken := tkArrayBegin;
  FState := AR;
  Result := True;
end;

function TJsonReader.ObjectBegin: Boolean;
begin
  if Depth = FStackHigh then exit(False);
  case FStack[Depth].Mode of
    pmNone: FStack[Succ(Depth)] := TLevel.Create(pmKey);
    pmArray:
      if ReadMode then
        FStack[Succ(Depth)] := TLevel.Create(pmKey, FStack[Depth].CurrIndex)
      else
        FStack[Succ(Depth)] := TLevel.Create(pmKey);
    pmObject:
      if ReadMode then
        FStack[Succ(Depth)] := TLevel.Create(pmKey, FName)
      else
        FStack[Succ(Depth)] := TLevel.Create(pmKey);
  else
    exit(False);
  end;
  Inc(FStackTop);
  FToken := tkObjectBegin;
  FState := OB;
  Result := True;
end;

function TJsonReader.ArrayEnd: Boolean;
begin
  if FStack[Depth].Mode <> pmArray then
    exit(False);
  Dec(FStackTop);
  FToken := tkArrayEnd;
  UpdateArray;
  FState := OK;
  Result := True;
end;

function TJsonReader.ArrayEndAfterNum: Boolean;
begin
  if FStack[Depth].Mode <> pmArray then
    exit(False);
  if not NumValue then
    exit(False);
  FDeferToken := tkArrayEnd;
  FState := OK;
  Result := True;
end;

function TJsonReader.ObjectEnd: Boolean;
begin
  if FStack[Depth].Mode <> pmObject then
    exit(False);
  Dec(FStackTop);
  FToken := tkObjectEnd;
  UpdateArray;
  FState := OK;
  Result := True;
end;

function TJsonReader.ObjectEndAfterNum: Boolean;
begin
  if FStack[Depth].Mode <> pmObject then
    exit(False);
  if not NumValue then
    exit(False);
  FDeferToken := tkObjectEnd;
  FState := OK;
  Result := True;
end;

function TJsonReader.ObjectEndOb: Boolean;
begin
  if FStack[Depth].Mode <> pmKey then
    exit(False);
  FToken := tkObjectEnd;
  Dec(FStackTop);
  UpdateArray;
  FState := OK;
  Result := True;
end;

function TJsonReader.DeferredEnd: Boolean;
begin
  case DeferToken of
    tkArrayEnd:  Result := ArrayEnd;
    tkObjectEnd: Result := ObjectEnd;
  else
    Result := False;
  end;
  FDeferToken := tkNone;
end;

function TJsonReader.GetNextChunk: TReadState;
begin
  if ReadState > rsGo then
    exit(ReadState);
  FPosition := NULL_INDEX;
  FByteCount := FStream.Read(FBuffer^, FBufSize);
  if FByteCount = 0 then
    begin
      FReadState := rsEOF;
      exit(ReadState);
    end;
  if FFirstChunk then
    begin
      FFirstChunk := False;
      if SkipBom then
        case DetectBom(PByte(FBuffer), FByteCount) of
          bkNone: ;
          bkUtf8: FPosition += UTF8_BOM_LEN;
        else
          FReadState := rsError;
          exit(ReadState);
        end;
      FReadState := rsGo;
    end;
  Result := ReadState;
end;

function TJsonReader.GetNextToken: Boolean;
var
  NextState, NextClass: Integer;
  c: AnsiChar;
begin
  repeat
    if DeferToken <> tkNone then exit(DeferredEnd);
    if (FPosition >= Pred(FByteCount)) and (GetNextChunk > rsGo) then
      exit(False);
    Inc(FPosition);
    c := FBuffer[FPosition];
    if c < #128 then begin
      NextClass := SymClassTable[Ord(c)];
      if NextClass = __ then exit(False);
    end else
      NextClass := Etc;
    NextState := StateTransitions[FState, NextClass];
    if NextState = __ then exit(False);
    if CopyMode then FsbHelp.Append(c); //////////
    if NextState < 31 then begin
      if (DWord(NextState - ST) < DWord(14)) and ReadMode then
        FsBuilder.Append(c);
      FState := NextState;
    end else
    case NextState of
      31: exit(ObjectEndOb);  //end object when state = OB
      32:                     //end object when state = OK or in [ZE, IR, FS, E3]
        if Integer(1 shl FState) and NUM_STATES = 0 then exit(ObjectEnd)
        else exit(ObjectEndAfterNum);

      33:                     //end array when state = OK or in [ZE, IR, FS, E3]
        if Integer(1 shl FState) and NUM_STATES = 0 then exit(ArrayEnd)
        else exit(ArrayEndAfterNum);
      34: exit(ObjectBegin);  //begin object
      35: exit(ArrayBegin);   //begin array
      36:                     //string value
        begin
          if ReadMode then
            FsBuilder.Append(c);
          if FStack[Depth].Mode = pmKey then NameValue
          else exit(StringValue);
        end;
      37:                     //OK - comma
        case FStack[Depth].Mode of
          pmObject: begin
              FStack[Depth].Mode := pmKey;
              FState := KE;
            end;
          pmArray: FState := VA;
        else exit(False);
        end;
      38:                     //colon
        if FStack[Depth].Mode = pmKey then begin
          FStack[Depth].Mode := pmObject;
          FState := VA;
        end else exit(False);
      39: exit(CommaAfterNum);//end number - comma
      40: begin               //end number - white space
        FState := OK;
        exit(NumValue);
      end;
      41: exit(TrueValue);    //true literal
      42: exit(FalseValue);   //false literal
      43: exit(NullValue);    //null literal
    else exit(False);
    end;
  until False;
end;

function TJsonReader.GetIsNull: Boolean;
begin
  Result := FValue.Kind = vkNull;
end;

function TJsonReader.GetAsBoolean: Boolean;
begin
  Result := FValue;
end;

function TJsonReader.GetAsNumber: Double;
begin
  Result := FValue;
end;

function TJsonReader.GetAsString: string;
begin
  Result := FValue;
end;

function TJsonReader.GetPath: string;
  procedure Convert(const s: string);
  var
    I: SizeInt;
  begin
    for I := 1 to System.Length(s) do
      case s[I] of
        '/':
          begin
            FsbHelp.Append('~');
            FsbHelp.Append('1');
          end;
        '~':
          begin
            FsbHelp.Append('~');
            FsbHelp.Append('0');
          end;
      else
        FsbHelp.Append(s[I]);
      end;
  end;
var
  I: SizeInt;
begin
  if FStackTop = 0 then
    exit('');
  for I := 2 to FStackTop do
    begin
      FsbHelp.Append('/');
      Convert(FStack[I].Path);
    end;
  if TokenKind in [tkNull, tkFalse, tkTrue, tkNumber, tkString] then
    begin
      FsbHelp.Append('/');
      Convert(Name);
    end;
  Result := FsbHelp.ToString;
end;

function TJsonReader.GetParentName: string;
begin
  Result := FStack[Depth].Path;
end;

function TJsonReader.GetParentIndex: SizeInt;
begin
  Result := FStack[Depth].CurrIndex;
end;

class function TJsonReader.IsStartToken(aToken: TTokenKind): Boolean;
begin
  Result := aToken in [tkArrayBegin, tkObjectBegin];
end;

class function TJsonReader.IsEndToken(aToken: TTokenKind): Boolean;
begin
  Result := aToken in [tkArrayEnd, tkObjectEnd];
end;

class function TJsonReader.IsScalarToken(aToken: TTokenKind): Boolean;
begin
  Result := aToken in [tkNull, tkFalse, tkTrue, tkNumber, tkString];
end;

constructor TJsonReader.Create(aStream: TStream; aBufSize: SizeInt; aMaxDepth: SizeInt; aSkipBom: Boolean);
begin
  FStream := aStream;
  if aBufSize < MIN_BUF_SIZE then
    aBufSize := MIN_BUF_SIZE;
  FBufSize := aBufSize;
  FBuffer := System.Getmem(FBufSize);
  if aMaxDepth < 31 then
    aMaxDepth := 31;
  System.SetLength(FStack, Succ(aMaxDepth));
  FStackHigh := aMaxDepth;
  FSkipBom := aSkipBom;
  FReadMode := True;
  FFirstChunk := True;
  FsBuilder := TJsonNode.TStrBuilder.Create(TJsonNode.S_BUILD_INIT_SIZE);
  FsbHelp := TJsonNode.TStrBuilder.Create(TJsonNode.S_BUILD_INIT_SIZE);
  FStack[0] := TLevel.Create(pmNone);
end;

destructor TJsonReader.Destroy;
begin
  System.Freemem(FBuffer);
  inherited;
end;

function TJsonReader.Read: Boolean;
begin
  if ReadState > rsGo then
    exit(False);
  Result := GetNextToken;
  if not Result then
    if ReadState = rsEOF then
      begin
        if Depth <> 0 then
          begin
            FReadState := rsError;
            exit;
          end;
        if Integer(1 shl FState) and NUM_STATES <> 0 then
          begin
            FState := OK;
            if NumValue then
              exit(True)
            else
              FReadState := rsError;
          end;
        if FState <> OK then
          FReadState := rsError;
      end
    else
      FReadState := rsError;
end;

procedure TJsonReader.Skip;
var
  OldDepth: SizeInt;
begin
  if ReadState > rsGo then exit;
  if IsStartToken(TokenKind) then
    begin
      OldDepth := Pred(Depth);
      FReadMode := False;
      try
        while Read and (Depth > OldDepth) do;
      finally
        FReadMode := True;
      end;
    end
  else
    Read;
end;

procedure TJsonReader.Iterate(aFun: TOnIterate);
var
  OldDepth: SizeInt;
begin
  if aFun = nil then exit;
  OldDepth := Depth;
  while Read do
    case TokenKind of
      tkNone,
      tkArrayBegin,
      tkObjectBegin: ;
      tkArrayEnd,
      tkObjectEnd:
        if Depth < OldDepth then
          break;
    else
      if not aFun(Self) then
        exit;
    end;
end;

procedure TJsonReader.Iterate(aFun: TNestIterate);
var
  OldDepth: SizeInt;
begin
  if aFun = nil then exit;
  OldDepth := Depth;
  while Read do
    case TokenKind of
      tkNone,
      tkArrayBegin,
      tkObjectBegin: ;
      tkArrayEnd,
      tkObjectEnd:
        if Depth < OldDepth then
          break;
    else
      if not aFun(Self) then
        exit;
    end;
end;

procedure TJsonReader.Iterate(aOnStruct, aOnValue: TOnIterate);
var
  OldDepth: SizeInt;
begin
  OldDepth := Depth;
  while Read do
    case TokenKind of
      tkNone,
      tkArrayEnd,
      tkObjectEnd:
        if Depth < OldDepth then
          break;
      tkArrayBegin,
      tkObjectBegin:
        if (aOnStruct <> nil) and not aOnStruct(Self) then
          exit;
    else
      if (aOnValue <> nil) and not aOnValue(Self) then
        exit;
    end;
end;

procedure TJsonReader.Iterate(aOnStruct, aOnValue: TNestIterate);
var
  OldDepth: SizeInt;
begin
  OldDepth := Depth;
  while Read do
    case TokenKind of
      tkNone,
      tkArrayEnd,
      tkObjectEnd:
        if Depth < OldDepth then
          break;
      tkArrayBegin,
      tkObjectBegin:
        if (aOnStruct <> nil) and not aOnStruct(Self) then
          exit;
    else
      if (aOnValue <> nil) and not aOnValue(Self) then
        exit;
    end;
end;

function TJsonReader.CopyStruct(out aStruct: string): Boolean;
begin
  if ReadState > rsGo then
    exit(False);
  if not IsStartToken(TokenKind) then
    exit(False);
  FsbHelp.MakeEmpty;
  if TokenKind = tkArrayBegin then
    FsbHelp.Append(chOpenSqrBr)
  else
    FsbHelp.Append(chOpenCurBr);
  FCopyMode := True;
  try
    Skip;
  finally
    FCopyMode := False;
  end;
  aStruct := FsbHelp.ToString;
  Result := True;
end;

function TJsonReader.MoveNext: Boolean;
begin
  if ReadState > rsGo then
    exit(False);
  if not Read then
    exit(False);
  if IsEndToken(TokenKind) then
    exit(False);
  if IsStartToken(TokenKind) then
    Skip;
  Result := True;
end;

function TJsonReader.Find(const aKey: string): Boolean;
var
  Idx, OldDepth: SizeInt;
begin
  if ReadState > rsGo then
    exit(False);
  case StructKind of
    skArray:
      begin
        if not IsNonNegativeInt(aKey, Idx) then
          exit(False);
        if Idx < Index then
          exit(False);
        OldDepth := Depth;
        while (FStack[OldDepth].CurrIndex < Idx) and MoveNext do;
        Result := (FStack[OldDepth].CurrIndex = Idx) and Read;
      end;
    skObject:
      begin
        if TokenKind = tkObjectBegin then
          Read;
        repeat
          if Name = aKey then exit(True);
          if IsStartToken(TokenKind) then
            Skip;
        until not Read or (TokenKind = tkObjectEnd);
        Result := False;
      end;
  else
    exit(False);
  end;
end;

function TJsonReader.FindPath(const aPtr: TJsonPtr): Boolean;
begin
  Result := FindPath(aPtr.ToSegments);
end;

function TJsonReader.FindPath(const aPath: TStringArray): Boolean;
var
  I: SizeInt;
begin
  if ReadState <> rsStart then
    exit(False);
  if not Read then
    exit(False);
  if aPath = nil then
    exit(True);
  for I := 0 to System.High(aPath) do
    if not Find(aPath[I]) then
      exit(False);
  Result := True;
end;

end.
