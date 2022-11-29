{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Miscellaneous classes and utils.                                        *
*                                                                           *
*   Copyright(c) 2018-2022 A.Koverdyaev(avk)                                *
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
unit lgMiscUtils;

{$MODE OBJFPC}{$H+}
{$MODESWITCH ADVANCEDRECORDS}
{$INLINE ON}
{$MODESWITCH NESTEDPROCVARS}
{$GOTO ON}

interface

uses

  Classes, SysUtils, math, FpJson,
  lgUtils,
  {%H-}lgHelpers,
  lgArrayHelpers,
  lgAbstractContainer,
  lgHashMap,
  lgJson,
  lgStrConst;

type

  { TGTimSortAnc: base ancestor class;
    Free Pascal port of java timsort implementation }
  generic TGTimSortAnc<T> = class
  public
  type
    TItem      = T;
    PItem      = ^T;

  protected
  type
    //to supress unnecessary refcounting
    TFake      = {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}array[0..Pred(SizeOf(T))] of Byte{$ELSE}T{$ENDIF};
    TFakeArray = array of TFake;

    TTimSortBase = object
    protected
    const
      MERGE_STACK_SIZE  = 64;
      MERGE_BUFFER_SIZE = 512;
      MIN_MERGE_POW     = 5;
      MIN_MERGE_LEN     = SizeInt(1) shl MIN_MERGE_POW;
      MIN_GALLOP        = 7;

    type
      TRun = record
        Base,
        Count: SizeInt;
      end;
      PRun      = ^TRun;
      TRunArray = array of TRun;

    var
      FBuffer: array[0..Pred(MERGE_BUFFER_SIZE)] of TFake;
      FInitStack: array[0..Pred(MERGE_STACK_SIZE)] of TRun;
      FData: PItem; // pointer to data array
      FDynBuffer: TFakeArray;
      FDynStack: TRunArray;
      FStack: PRun;
      FStackCount,
      FStackSize,
      FMinGallop: SizeInt;
      procedure PushRun(aBase, aCount: SizeInt);
      function  EnsureBufferSize(aSize: SizeInt): PItem;
      procedure Init(A: PItem);
      procedure Swap(Base1, Len1, Base2, Len2: SizeInt);
      class function  MinRunLen(aTotalSize: SizeInt): SizeInt; static;
      class procedure DoReverse(p: PItem; R: SizeInt); static;
    end;

  end;

  { TGBaseTimSort
      functor TCmpRel (comparison relation) must provide:
        class function Less([const[ref]] L, R: T): Boolean; }
  generic TGBaseTimSort<T, TCmpRel> = class(specialize TGTimSortAnc<T>)
  protected
  type
    TTimSort = object(TTimSortBase)
    protected
      procedure CollapseA;
      procedure CollapseD;
      procedure ForceCollapseA;
      procedure ForceCollapseD;
      procedure MergeAtA(aIndex: SizeInt);
      procedure MergeAtD(aIndex: SizeInt);
      function  GallopLeftA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopLeftD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopRightA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopRightD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      procedure MergeLoA(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeLoD(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeHiA(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeHiD(Base1, Len1, Base2, Len2: SizeInt);
      class procedure InsertSortA(A: PItem; R, At: SizeInt); static;
      class procedure InsertSortD(A: PItem; R, At: SizeInt); static;
      class function  CountRunAsc(A: PItem; R: SizeInt): SizeInt; static;
      class function  CountRunDesc(A: PItem; R: SizeInt): SizeInt; static;
    public
      class procedure SortAsc(A: PItem; R: SizeInt); static;
      class procedure SortDesc(A: PItem; R: SizeInt); static;
    end;

  public
    class procedure Sort(var A: array of T; aOrder: TSortOrder = soAsc); static;
  end;

  { TGTimSort assumes that type T has implemented TCmpRel }
  generic TGTimSort<T> = class(specialize TGBaseTimSort<T, T>);

  { TGComparableTimSort assumes that type T has defined comparison operator < }
  generic TGComparableTimSort<T> = class(specialize TGTimSortAnc<T>)
  protected
  type
    TTimSort = object(TTimSortBase)
    protected
      procedure CollapseA;
      procedure CollapseD;
      procedure ForceCollapseA;
      procedure ForceCollapseD;
      procedure MergeAtA(aIndex: SizeInt);
      procedure MergeAtD(aIndex: SizeInt);
      function  GallopLeftA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopLeftD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopRightA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopRightD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      procedure MergeLoA(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeLoD(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeHiA(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeHiD(Base1, Len1, Base2, Len2: SizeInt);
      class procedure InsertSortA(A: PItem; R, At: SizeInt); static;
      class procedure InsertSortD(A: PItem; R, At: SizeInt); static;
      class function  CountRunAsc(A: PItem; R: SizeInt): SizeInt; static;
      class function  CountRunDesc(A: PItem; R: SizeInt): SizeInt; static;
    public
      class procedure SortAsc(A: PItem; R: SizeInt); static;
      class procedure SortDesc(A: PItem; R: SizeInt); static;
    end;

  public
    class procedure Sort(var A: array of T; aOrder: TSortOrder = soAsc); static;
  end;

  { TGRegularTimSort: TimSort with regular comparator }
  generic TGRegularTimSort<T> = class(specialize TGTimSortAnc<T>)
  public
  type
    TLess = specialize TGLessCompare<T>;

  protected
  type
    TTimSort = object(TTimSortBase)
    protected
      FLess: TLess;
      procedure Init(A: PItem; c: TLess);
      procedure CollapseA;
      procedure CollapseD;
      procedure ForceCollapseA;
      procedure ForceCollapseD;
      procedure MergeAtA(aIndex: SizeInt);
      procedure MergeAtD(aIndex: SizeInt);
      function  GallopLeftA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopLeftD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopRightA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopRightD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      procedure MergeLoA(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeLoD(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeHiA(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeHiD(Base1, Len1, Base2, Len2: SizeInt);
      class procedure InsertSortA(A: PItem; R, At: SizeInt; c: TLess); static;
      class procedure InsertSortD(A: PItem; R, At: SizeInt; c: TLess); static;
      class function  CountRunAsc(A: PItem; R: SizeInt; c: TLess): SizeInt; static;
      class function  CountRunDesc(A: PItem; R: SizeInt; c: TLess): SizeInt; static;
    public
      class procedure SortAsc(A: PItem; R: SizeInt; c: TLess); static;
      class procedure SortDesc(A: PItem; R: SizeInt; c: TLess); static;
    end;

  public
    class procedure Sort(var A: array of T; c: TLess; aOrder: TSortOrder = soAsc); static;
  end;

  { TGDelegatedTimSort: TimSort with delegated comparator }
  generic TGDelegatedTimSort<T> = class(specialize TGTimSortAnc<T>)
  public
  type
    TOnLess = specialize TGOnLessCompare<T>;

  protected
  type
    TTimSort = object(TTimSortBase)
    protected
      FLess: TOnLess;
      procedure Init(A: PItem; c: TOnLess);
      procedure CollapseA;
      procedure CollapseD;
      procedure ForceCollapseA;
      procedure ForceCollapseD;
      procedure MergeAtA(aIndex: SizeInt);
      procedure MergeAtD(aIndex: SizeInt);
      function  GallopLeftA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopLeftD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopRightA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopRightD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      procedure MergeLoA(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeLoD(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeHiA(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeHiD(Base1, Len1, Base2, Len2: SizeInt);
      class procedure InsertSortA(A: PItem; R, At: SizeInt; c: TOnLess); static;
      class procedure InsertSortD(A: PItem; R, At: SizeInt; c: TOnLess); static;
      class function  CountRunAsc(A: PItem; R: SizeInt; c: TOnLess): SizeInt; static;
      class function  CountRunDesc(A: PItem; R: SizeInt; c: TOnLess): SizeInt; static;
    public
      class procedure SortAsc(A: PItem; R: SizeInt; c: TOnLess); static;
      class procedure SortDesc(A: PItem; R: SizeInt; c: TOnLess); static;
    end;

  public
    class procedure Sort(var A: array of T; c: TOnLess; aOrder: TSortOrder = soAsc); static;
  end;

  { TGNestedTimSort: TimSort with nested comparator }
  generic TGNestedTimSort<T> = class(specialize TGTimSortAnc<T>)
  public
  type
    TNestLess = specialize TGNestLessCompare<T>;

  protected
  type
    TTimSort = object(TTimSortBase)
    protected
      FLess: TNestLess;
      procedure Init(A: PItem; c: TNestLess);
      procedure CollapseA;
      procedure CollapseD;
      procedure ForceCollapseA;
      procedure ForceCollapseD;
      procedure MergeAtA(aIndex: SizeInt);
      procedure MergeAtD(aIndex: SizeInt);
      function  GallopLeftA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopLeftD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopRightA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      function  GallopRightD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
      procedure MergeLoA(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeLoD(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeHiA(Base1, Len1, Base2, Len2: SizeInt);
      procedure MergeHiD(Base1, Len1, Base2, Len2: SizeInt);
      class procedure InsertSortA(A: PItem; R, At: SizeInt; c: TNestLess); static;
      class procedure InsertSortD(A: PItem; R, At: SizeInt; c: TNestLess); static;
      class function  CountRunAsc(A: PItem; R: SizeInt; c: TNestLess): SizeInt; static;
      class function  CountRunDesc(A: PItem; R: SizeInt; c: TNestLess): SizeInt; static;
    public
      class procedure SortAsc(A: PItem; R: SizeInt; c: TNestLess); static;
      class procedure SortDesc(A: PItem; R: SizeInt; c: TNestLess); static;
    end;

  public
    class procedure Sort(var A: array of T; c: TNestLess; aOrder: TSortOrder = soAsc); static;
  end;

  { TTextFileReader is small wrapper around TextFile to mimic string enumerable with buffered read as a bonus;
     it isn't understand 'Input' or 'StdIn' as FileName; }
  TTextFileReader = class sealed(specialize TGEnumerable<string>)
  private
  type
    TEnumerator = class(TSpecEnumerator)
    private
      FReader: TTextFileReader;
    protected
      function  GetCurrent: string; override;
    public
      constructor Create(aReader: TTextFileReader);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

  var
    FFile: TextFile;
    FFileName,
    FCurrent,
    FExceptClass,
    FExceptMsg: string;
    FBuffer: array[0..511] of QWord; //????
    FIsOpen: Boolean;
    procedure Close;
    function  GetFile: PText; inline;
  protected
    function  GetCurrent: string; //inline;
    function  MoveNext: Boolean; //inline;
    procedure Reset; //inline;
    property  IsOpen: Boolean read FIsOpen;
  public
    class function FileExists(const aFileName: string): Boolean; static;
    class function FileSize(const aFileName: string): Int64; static;
    destructor Destroy; override;
    function GetEnumerator: TEnumerator; override;
    function Open(const aFileName: string): Boolean;
    function LoadText(const aFileName: string; out aText: string): Boolean;
    property ExceptionClass: string read FExceptClass;
    property ExceptionMessage: string read FExceptMsg;
    property InFile: PText read GetFile;
  end;

  { TTextFileWriter is small wrapper around TextFile with buffered write as a bonus;
     it understand 'Output', 'StdOut' and 'StdErr' as file names in case-insensitive manner }
  TTextFileWriter = class sealed
  private
  const
    sOutput = 'output';
    sStdOut = 'stdout';
    sStdErr = 'stderr';

  var
    FFile: TextFile;
    FFileName,
    FExceptClass,
    FExceptMsg: string;
    FBuffer: array[0..511] of QWord;
    FIsOpen,
    FIsStandard,
    FAppend: Boolean;
    function  GetFile: PText; inline;
    function  IsStandardFile: Boolean; inline;
    procedure Open;
    procedure AppendFile;
    procedure Close;
    property  IsStandard: Boolean read FIsStandard;
  public
  type
    IStringEnumerable = specialize IGEnumerable<string>;
    constructor Create(const aFileName: string = ''; Append: Boolean = False);
    destructor Destroy; override;
    procedure AfterConstruction; override;
    function Add(const aValue: string): Boolean;
    function AddAll(const a: array of string): SizeInt;
    function AddAll(e: IStringEnumerable): SizeInt;
    property FileName: string read FFileName;
    property IsOpen: Boolean read FIsOpen;
    property ExceptionClass: string read FExceptClass;
    property ExceptionMessage: string read FExceptMsg;
    property OutFile: PText read GetFile;
  end;

  { TGetEnumerable: TEnumerator must be a value type }
  generic TGetEnumerable<T, TEnumerator> = class(specialize TGAutoEnumerable<T>)
  protected
    FEnum,
    FWorkEnum: TEnumerator;
    function GetCurrent: T; override;
  public
    class function Construct(const aEnum: TEnumerator): IEnumerable; static; inline;
    constructor Create(const aEnum: TEnumerator);
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  { TGClassEnumerable: class TEntity must have a GetEnumerator method that returns
    a value of type TEnumerator; TEnumerator must be a class }
  generic TGClassEnumerable<T, TEntity, TEnumerator> = class(specialize TGAutoEnumerable<T>)
  protected
    FEntity: TEntity;
    FEnum: TEnumerator;
    function GetCurrent: T; override;
  public
    class function Construct(aEntity: TEntity): IEnumerable; static; inline;
    constructor Create(aEntity: TEntity);
    destructor Destroy; override;
    function  MoveNext: Boolean; override;
    procedure Reset; override;
  end;

  { TGBaseLruCache wraps a (heavy)user function OnGetValue with a memoized method
    GetValue that saves up to the SizeLimit most recent results }
  generic TGBaseLruCache<TKey, TValue, TKeyEqRel> = class
  public
  type
    TOnGetValue = function(const aKey: TKey): TValue of object;
  protected
  type
    TMap = class(specialize TGBaseOrderedHashMap<TKey, TValue, TKeyEqRel>);
  var
    FMap: TMap;
    FGetValue: TOnGetValue;
    FSizeLimit: SizeInt;
    function  GetLoadFactor: Single;
    procedure SetSizeLimit(aValue: SizeInt);
    procedure SetLoadFactor(aValue: Single);
  public
    constructor Create(aGetValue: TOnGetValue; aSizeLimit: SizeInt);
    constructor Create(aGetValue: TOnGetValue; aSizeLimit: SizeInt; aLoadFactor: Single);
    constructor Create(aGetValue: TOnGetValue; aSizeLimit, aCapacity: SizeInt; aLoadFactor: Single);
    destructor Destroy; override;
    procedure Clear;
    procedure TrimToFit;
    function  GetValue(const aKey: TKey): TValue;
    property  SizeLimit: SizeInt read FSizeLimit write SetSizeLimit;
    property  OnGetValue: TOnGetValue read FGetValue;
    property  LoadFactor: Single read GetLoadFactor write SetLoadFactor;
  end;

  TParamKind = (pkOption, pkLongOption, pkArgument);

  TCmdLineOption = record
    Kind:  TParamKind;
    Key:   string;
    Value: string;
  end;

  TCmdLineOptions = array of TCmdLineOption;

  function CmdLineOptions: TCmdLineOptions;

  function JsonNode2Data(aNode: TJsonNode): TJsonData;
  function JsonData2Node(aData: TJsonData): TJsonNode;

implementation
{$B-}{$COPERATORS ON}

type

  TCmdLine = class sealed
  private
  const
    EQ        = '=';
    COLON     = ':';
    SEP_CHARS = [EQ, COLON];
    OPT_CHAR  = '-';
    INIT_SIZE = 4;
  class var
    Options: TCmdLineOptions;
    class procedure ParseOptions; static;
  public
    class function GetOptions: TCmdLineOptions; static;
  end;

function CmdLineOptions: TCmdLineOptions;
begin
  Result := TCmdLine.GetOptions;
end;

class procedure TCmdLine.ParseOptions;
var

  CurrParam: string;
  I, Count: SizeInt;
  o: TCmdLineOption;

  procedure ItemAdding;
  begin
    if Count = System.Length(Options) then
      System.SetLength(Options, System.Length(Options) * 2);
  end;

  procedure OptionAdd(const aOption: TCmdLineOption);
  begin
    ItemAdding;
    Options[Count] := aOption;
    Inc(Count);
  end;
  function IsKeyValue(const aOpt: string; out aKey, aValue: string): Boolean;
  var
    I: SizeInt;
    DivPos: SizeInt;
  begin
    if System.Length(aOpt) < 3 then
      exit(False);
    DivPos := 0;
    for I := 2 to System.Length(aOpt) - 1 do //ignore separator on first and last position
      if aOpt[I] in SEP_CHARS then           //only first match matter
        begin
          DivPos := I;
          break;
        end;
    Result := DivPos > 0;
    if Result then
      begin
        aKey := Copy(aOpt, 1, DivPos - 1);
        aValue := Copy(aOpt, DivPos + 1, System.Length(aOpt) - DivPos);
      end;
  end;

  procedure ParseLongOption(const aValue: string);
  var
    k, v: string;
  begin
    if aValue = '' then
      exit;
    o.Kind := pkLongOption;
    if IsKeyValue(aValue, k, v) then
      begin
       o.Key := k;
       o.Value := v;
      end
    else
      begin
        o.Key := aValue;
        o.Value := '';
      end;
    OptionAdd(o);
  end;

  procedure ParseShortOption(const aValue: string);
  var
    I: SizeInt;
    k, v: string;
  begin
    if aValue = '' then
      exit;
    o.Kind := pkOption;
    if IsKeyValue(aValue, k, v) then
      begin
        for I := 1 to System.Length(k) - 1 do     //-abc=de -> a, b, c=de
          begin                                   //-a=bcde -> a=bcde
            o.Key := k[I];
            o.Value := '';
            OptionAdd(o);
          end;
        o.Key := k[System.Length(k)];
        o.Value := v;
        OptionAdd(o);
      end
    else
      for I := 1 to System.Length(aValue) do
        begin
          o.Key := aValue[I];
          o.Value := '';
          OptionAdd(o);
        end;
  end;
  procedure ParseOption(const aValue: string);
  begin
    if aValue = '' then
      exit;
    if aValue[1] = OPT_CHAR then
      ParseLongOption(Copy(aValue, 2, System.Length(aValue) - 1))
    else
      ParseShortOption(aValue);
  end;
  procedure ParseParam(const aParam: string);
  begin
    o.Kind := pkArgument;
    o.Key := '';
    o.Value := aParam;
    OptionAdd(o);
  end;
begin
  Count := 0;
  System.SetLength(Options, INIT_SIZE);
  for I := 1 to System.ParamCount do
    begin
      CurrParam := System.ParamStr(I);
      if CurrParam = '' then
        continue;
      if CurrParam[1] = OPT_CHAR then
        ParseOption(Copy(CurrParam, 2, System.Length(CurrParam) - 1))
      else
        ParseParam(CurrParam);
    end;
  System.SetLength(Options, Count);
end;

class function TCmdLine.GetOptions: TCmdLineOptions;
begin
  if Options = nil then
    ParseOptions;
  Result := System.Copy(Options, 0, System.Length(Options)) ;
end;

{$PUSH}{$WARN 4046 OFF}
function JsonNode2Data(aNode: TJsonNode): TJsonData;
  function CopyNode(aNode: TJsonNode): TJsonData;
  var
    I: SizeInt;
  begin
    case aNode.Kind of
      jvkUnknown: Result := TJsonData.Create;
      jvkNull:    Result := CreateJson;
      jvkFalse:   Result := CreateJson(False);
      jvkTrue:    Result := CreateJson(True);
      jvkNumber:  Result := CreateJson(aNode.AsNumber);
      jvkString:  Result := CreateJson(aNode.AsString);
      jvkArray:
        begin
          Result := TJsonArray.Create;
          for I := 0 to Pred(aNode.Count) do
            TJsonArray(Result).Add(CopyNode(aNode.Items[I]));
        end;
      jvkObject:
        begin
          Result := TJsonObject.Create;
          for I := 0 to Pred(aNode.Count) do
            with aNode.Pairs[I] do
              TJsonObject(Result).Add(Key, CopyNode(Value));
        end;
    end;
  end;
begin
  if aNode = nil then
    exit(nil);
  Result := CopyNode(aNode);
end;
{$POP}

function JsonData2Node(aData: TJsonData): TJsonNode;
  procedure CopyData(aSrc: TJsonData; aDst: TJsonNode);
  var
    I: SizeInt;
    e: TJsonEnum;
  begin
    case aSrc.JSONType of
      jtUnknown: ;
      jtNull:    aDst.AsNull;
      jtBoolean: aDst.AsBoolean := aSrc.AsBoolean;
      jtNumber:  aDst.AsNumber := aSrc.AsFloat;
      jtString:  aDst.AsString := aSrc.AsString;
      jtArray:
        begin
          aDst.AsArray;
          for I := 0 to Pred(aSrc.Count) do
            CopyData(aSrc.Items[I], aDst.AddNode);
        end;
      jtObject:
        begin
          aDst.AsObject;
          for e in aSrc do
            CopyData(e.Value, aDst.AddNode(e.Key));
        end;
    end;
  end;
begin
  if aData = nil then
    exit(nil);
  Result := TJsonNode.Create;
  CopyData(aData, Result);
end;

{ TGTimSortAnc.TTimSortBase }

procedure TGTimSortAnc.TTimSortBase.PushRun(aBase, aCount: SizeInt);
begin
  if FStackCount = FStackSize then
    begin
      FStackSize += FStackSize;
      System.SetLength(FDynStack, FStackSize );
      if FStack = @FInitStack[0] then
        System.Move(FInitStack[0], Pointer(FDynStack)^, MERGE_STACK_SIZE * SizeOf(TRun));
      FStack := Pointer(FDynStack);
    end;
  FStack[FStackCount].Base := aBase;
  FStack[FStackCount].Count := aCount;
  Inc(FStackCount);
end;

function TGTimSortAnc.TTimSortBase.EnsureBufferSize(aSize: SizeInt): PItem;
begin
  if aSize > MERGE_BUFFER_SIZE then
    begin
      if aSize > System.Length(FDynBuffer) then
        System.SetLength(FDynBuffer, LGUtils.RoundUpTwoPower(aSize));
      Result := Pointer(FDynBuffer);
    end
  else
    Result := Pointer(@FBuffer[0]);
end;

procedure TGTimSortAnc.TTimSortBase.Init(A: PItem);
begin
  FData := A;
  FStackCount := 0;
  FStackSize := MERGE_STACK_SIZE;
  FMinGallop := MIN_GALLOP;
  FDynBuffer := nil;
  FDynStack := nil;
  FStack := @FInitStack[0];
end;

procedure TGTimSortAnc.TTimSortBase.Swap(Base1, Len1, Base2, Len2: SizeInt);
var
  LocB: PItem;
begin
  if Len1 <= Len2 then
    begin
      LocB := EnsureBufferSize(Len1);
      System.Move(FData[Base1], LocB[0], Len1 * SizeOf(T));
      System.Move(FData[Base2], FData[Base1], Len2 * SizeOf(T));
      System.Move(LocB[0], FData[Base1 + Len2], Len1 * SizeOf(T));
    end
  else
    begin
      LocB := EnsureBufferSize(Len2);
      System.Move(FData[Base2], LocB[0], Len2 * SizeOf(T));
      System.Move(FData[Base1], FData[Base1 + Len2], Len1 * SizeOf(T));
      System.Move(LocB[0], FData[Base1], Len2 * SizeOf(T));
    end;
end;

class function TGTimSortAnc.TTimSortBase.MinRunLen(aTotalSize: SizeInt): SizeInt;
var
  s: SizeInt;
begin
  if aTotalSize > MIN_MERGE_LEN then
    begin
      s := LGUtils.NSB(aTotalSize) - MIN_MERGE_POW;
      Result := aTotalSize shr s;
      Result += Ord((Result shl s xor aTotalSize) <> 0);
    end
  else
    Result := aTotalSize;
end;

class procedure TGTimSortAnc.TTimSortBase.DoReverse(p: PItem; R: SizeInt);
var
  v0, v1, v2, v3: TFake;
  L: SizeInt;
begin
  L := 0;
  while R - L >= 7 do
    begin
      v0 := TFake(p[L    ]);
      v1 := TFake(p[L + 1]);
      v2 := TFake(p[L + 2]);
      v3 := TFake(p[L + 3]);
      TFake(p[L    ]) := TFake(p[R    ]);
      TFake(p[L + 1]) := TFake(p[R - 1]);
      TFake(p[L + 2]) := TFake(p[R - 2]);
      TFake(p[L + 3]) := TFake(p[R - 3]);
      TFake(p[R    ]) := v0;
      TFake(p[R - 1]) := v1;
      TFake(p[R - 2]) := v2;
      TFake(p[R - 3]) := v3;
      L += 4;
      R -= 4;
    end;
  case R - L of
    1..2:
      begin
        v0 := TFake(p[L]);
        TFake(p[L]) := TFake(p[R]);
        TFake(p[R]) := v0;
      end;
    3..4:
      begin
        v0 := TFake(p[L    ]);
        v1 := TFake(p[L + 1]);
        TFake(p[L    ]) := TFake(p[R    ]);
        TFake(p[L + 1]) := TFake(p[R - 1]);
        TFake(p[R    ]) := v0;
        TFake(p[R - 1]) := v1;
      end;
    5..6:
      begin
        v0 := TFake(p[L    ]);
        v1 := TFake(p[L + 1]);
        v2 := TFake(p[L + 2]);
        TFake(p[L    ]) := TFake(p[R    ]);
        TFake(p[L + 1]) := TFake(p[R - 1]);
        TFake(p[L + 2]) := TFake(p[R - 2]);
        TFake(p[R    ]) := v0;
        TFake(p[R - 1]) := v1;
        TFake(p[R - 2]) := v2;
      end;
  end;
end;

{ TGBaseTimSort.TTimSort }

procedure TGBaseTimSort.TTimSort.CollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtA(I);
    end;
end;

procedure TGBaseTimSort.TTimSort.CollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtD(I);
    end;
end;

procedure TGBaseTimSort.TTimSort.ForceCollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtA(I - 1)
      else
        MergeAtA(I);
    end;
end;

procedure TGBaseTimSort.TTimSort.ForceCollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtD(I - 1)
      else
        MergeAtD(I);
    end;
end;

procedure TGBaseTimSort.TTimSort.MergeAtA(aIndex: SizeInt);
var
  Base1, Len1, Base2, Len2, D: SizeInt;
begin
  Base1 := FStack[aIndex].Base;
  Len1 := FStack[aIndex].Count;
  Base2 := FStack[aIndex + 1].Base;
  Len2 := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := Len1 + Len2;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if TCmpRel.Less(FData[Base2], FData[Pred(Base2)]) then
    begin
      D := GallopRightA(FData, FData[Base2], Base1, Len1, 0);
      Base1 += D;
      Len1 -= D;
      if Len1 > 0 then
        if not TCmpRel.Less(FData[Pred(Base2 + Len2)], FData[Base1]) then
          begin
            Len2 := GallopLeftA(FData, FData[Pred(Base1 + Len1)], Base2, Len2, Len2 - 1);
            if Len2 > 0 then
              if Len1 <= Len2 then
                MergeLoA(Base1, Len1, Base2, Len2)
              else
                MergeHiA(Base1, Len1, Base2, Len2);
          end
        else
          Swap(Base1, Len1, Base2, Len2);
    end;
end;

procedure TGBaseTimSort.TTimSort.MergeAtD(aIndex: SizeInt);
var
  Base1, Len1, Base2, Len2, D: SizeInt;
begin
  Base1 := FStack[aIndex].Base;
  Len1 := FStack[aIndex].Count;
  Base2 := FStack[aIndex + 1].Base;
  Len2 := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := Len1 + Len2;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if TCmpRel.Less(FData[Pred(Base2)], FData[Base2]) then
    begin
      D := GallopRightD(FData, FData[Base2], Base1, Len1, 0);
      Base1 += D;
      Len1 -= D;
      if Len1 > 0 then
        if not TCmpRel.Less(FData[Base1], FData[Pred(Base2 + Len2)]) then
          begin
            Len2 := GallopLeftD(FData, FData[Pred(Base1 + Len1)], Base2, Len2, Len2 - 1);
            if Len2 > 0 then
              if Len1 <= Len2 then
                MergeLoD(Base1, Len1, Base2, Len2)
              else
                MergeHiD(Base1, Len1, Base2, Len2);
          end
        else
          Swap(Base1, Len1, Base2, Len2);
    end;
end;

function TGBaseTimSort.TTimSort.GallopLeftA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
begin
  Dist := 0;
  Result := 1;
  if TCmpRel.Less(A[Base + Hint], Key) then
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and TCmpRel.Less(A[Base + Hint + Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then  //
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end
  else
    begin
      MaxDist := Hint + 1;
      while (Result < MaxDist) and not TCmpRel.Less(A[Base + Hint - Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then   //
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if TCmpRel.Less(A[Base + M], Key) then
        Dist := Succ(M)
      else
        Result := M;
    end;
end;

function TGBaseTimSort.TTimSort.GallopLeftD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
begin
  Dist := 0;
  Result := 1;
  if TCmpRel.Less(Key, A[Base + Hint]) then
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and TCmpRel.Less(Key, A[Base + Hint + Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then  //
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end
  else
    begin
      MaxDist := Hint + 1;
      while (Result < MaxDist) and not TCmpRel.Less(Key, A[Base + Hint - Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then   //
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if TCmpRel.Less(Key, A[Base + M]) then
        Dist := Succ(M)
      else
        Result := M;
    end;
end;

function TGBaseTimSort.TTimSort.GallopRightA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
begin
  Dist := 0;
  Result := 1;
  if TCmpRel.Less(Key, A[Base + Hint]) then
    begin
      MaxDist := Succ(Hint);
      while (Result < MaxDist) and TCmpRel.Less(Key, A[Base + Hint - Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end
  else
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and not TCmpRel.Less(Key, A[Base + Hint + Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if TCmpRel.Less(Key, A[Base + M]) then
        Result := M
      else
        Dist := Succ(M);
    end;
end;

function TGBaseTimSort.TTimSort.GallopRightD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
begin
  Dist := 0;
  Result := 1;
  if TCmpRel.Less(A[Base + Hint], Key) then
    begin
      MaxDist := Succ(Hint);
      while (Result < MaxDist) and TCmpRel.Less(A[Base + Hint - Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end
  else
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and not TCmpRel.Less(A[Base + Hint + Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if TCmpRel.Less(A[Base + M], Key) then
        Result := M
      else
        Dist := Succ(M);
    end;
end;

procedure TGBaseTimSort.TTimSort.MergeLoA(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in buffer)
  pHi,             // position in high part  (in data array)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data
  LocB: PItem;     // local pointer to buffer
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len1);
  System.Move(LocA[Base1], LocB[0], Len1 * SizeOf(T));
  pLo := 0;
  pHi := Base2;
  pDst := Base1;
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if not TCmpRel.Less(LocA[pHi], LocB[pLo]) then
        begin
          TFake(LocA[pDst]) := TFake(LocB[pLo]);
          Inc(pDst);
          Inc(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocA[pHi]);
          Inc(pDst);
          Inc(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := GallopRightA(@LocB[0], LocA[pHi], pLo, Len1, 0);
      if Count1 <> 0 then
        begin
          System.Move(LocB[pLo], LocA[pDst], Count1 * SizeOf(T));
          Len1 -= Count1;
          pDst += Count1;
          pLo += Count1;
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pHi]);
      Dec(Len2);
      Inc(pDst);
      Inc(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := GallopLeftA(LocA, LocB[pLo], pHi, Len2, 0);
      if Count2 <> 0 then
        begin
          System.Move(LocA[pHi], LocA[pDst], Count2 * SizeOf(T));
          Len2 -= Count2;
          pDst += Count2;
          pHi += Count2;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pLo]);
      Dec(Len1);
      Inc(pDst);
      Inc(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len1 > 0 then
    System.Move(LocB[pLo], LocA[pDst], Len1 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGBaseTimSort.TTimSort.MergeLoD(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in buffer)
  pHi,             // position in high part  (in data array)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data
  LocB: PItem;     // local pointer to buffer
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len1);
  System.Move(LocA[Base1], LocB[0], Len1 * SizeOf(T));
  pLo := 0;
  pHi := Base2;
  pDst := Base1;
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if not TCmpRel.Less(LocB[pLo], LocA[pHi]) then
        begin
          TFake(LocA[pDst]) := TFake(LocB[pLo]);
          Inc(pDst);
          Inc(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocA[pHi]);
          Inc(pDst);
          Inc(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := GallopRightD(@LocB[0], LocA[pHi], pLo, Len1, 0);
      if Count1 <> 0 then
        begin
          System.Move(LocB[pLo], LocA[pDst], Count1 * SizeOf(T));
          Len1 -= Count1;
          pDst += Count1;
          pLo += Count1;
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pHi]);
      Dec(Len2);
      Inc(pDst);
      Inc(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := GallopLeftD(LocA, LocB[pLo], pHi, Len2, 0);
      if Count2 <> 0 then
        begin
          System.Move(LocA[pHi], LocA[pDst], Count2 * SizeOf(T));
          Len2 -= Count2;
          pDst += Count2;
          pHi += Count2;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pLo]);
      Dec(Len1);
      Inc(pDst);
      Inc(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len1 > 0 then
    System.Move(LocB[pLo], LocA[pDst], Len1 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGBaseTimSort.TTimSort.MergeHiA(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in data array)
  pHi,             // position in high part  (in buffer)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data array
  LocB: PItem;     // local pointer to buffer
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len2);
  System.Move(LocA[Base2], LocB[0], Len2 * SizeOf(T));
  pLo := Pred(Base1 + Len1);
  pHi := Pred(Len2);
  pDst := Pred(Base2 + Len2);
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if TCmpRel.Less(LocB[pHi], LocA[pLo]) then
        begin
          TFake(LocA[pDst]) := TFake(LocA[pLo]);
          Dec(pDst);
          Dec(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocB[pHi]);
          Dec(pDst);
          Dec(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := Len1 - GallopRightA(LocA, LocB[pHi], Base1, Len1, Pred(Len1));
      if Count1 <> 0 then
        begin
          Len1 -= Count1;
          pDst -= Count1;
          pLo -= Count1;
          System.Move(LocA[Succ(pLo)], LocA[Succ(pDst)], Count1 * SizeOf(T));
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pHi]);
      Dec(Len2);
      Dec(pDst);
      Dec(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := Len2 - GallopLeftA(@LocB[0], LocA[pLo], 0, Len2, Pred(Len2));
      if Count2 <> 0 then
        begin
          Len2 -= Count2;
          pDst -= Count2;
          pHi -= Count2;
          System.Move(LocB[Succ(pHi)], LocA[Succ(pDst)], Count2 * SizeOf(T));
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pLo]);
      Dec(Len1);
      Dec(pDst);
      Dec(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len2 > 0 then
    System.Move(LocB[0], LocA[Succ(pDst - Len2)], Len2 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGBaseTimSort.TTimSort.MergeHiD(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in data array)
  pHi,             // position in high part  (in buffer)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data array
  LocB: PItem;     // local pointer to buffer
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len2);
  System.Move(LocA[Base2], LocB[0], Len2 * SizeOf(T));
  pLo := Pred(Base1 + Len1);
  pHi := Pred(Len2);
  pDst := Pred(Base2 + Len2);
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if TCmpRel.Less(LocA[pLo], LocB[pHi]) then
        begin
          TFake(LocA[pDst]) := TFake(LocA[pLo]);
          Dec(pDst);
          Dec(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocB[pHi]);
          Dec(pDst);
          Dec(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := Len1 - GallopRightD(LocA, LocB[pHi], Base1, Len1, Pred(Len1));
      if Count1 <> 0 then
        begin
          Len1 -= Count1;
          pDst -= Count1;
          pLo -= Count1;
          System.Move(LocA[Succ(pLo)], LocA[Succ(pDst)], Count1 * SizeOf(T));
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pHi]);
      Dec(Len2);
      Dec(pDst);
      Dec(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := Len2 - GallopLeftD(@LocB[0], LocA[pLo], 0, Len2, Pred(Len2));
      if Count2 <> 0 then
        begin
          Len2 -= Count2;
          pDst -= Count2;
          pHi -= Count2;
          System.Move(LocB[Succ(pHi)], LocA[Succ(pDst)], Count2 * SizeOf(T));
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pLo]);
      Dec(Len1);
      Dec(pDst);
      Dec(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len2 > 0 then
    System.Move(LocB[0], LocA[Succ(pDst - Len2)], Len2 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

class procedure TGBaseTimSort.TTimSort.InsertSortA(A: PItem; R, At: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and TCmpRel.Less(T(v), A[J]) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class procedure TGBaseTimSort.TTimSort.InsertSortD(A: PItem; R, At: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and TCmpRel.Less(A[J], T(v)) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class function TGBaseTimSort.TTimSort.CountRunAsc(A: PItem; R: SizeInt): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not TCmpRel.Less(A[1], A[0]) then  // ascending
        while (Result < R) and not TCmpRel.Less(A[Succ(Result)], A[Result]) do
          Inc(Result)
      else                                  // descending
        begin
          while (Result < R) and TCmpRel.Less(A[Succ(Result)], A[Result]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class function TGBaseTimSort.TTimSort.CountRunDesc(A: PItem; R: SizeInt): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not TCmpRel.Less(A[0], A[1]) then  // descending
        while (Result < R) and not TCmpRel.Less(A[Result], A[Succ(Result)]) do
          Inc(Result)
      else                                  // ascending
        begin
          while (Result < R) and TCmpRel.Less(A[Result], A[Succ(Result)]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class procedure TGBaseTimSort.TTimSort.SortAsc(A: PItem; R: SizeInt);
var
  RunLen, MinLen, Len, L: SizeInt;
  ts: TTimSort;
begin
  if R >= MIN_MERGE_LEN shl 1 then
    begin
      ts.Init(A);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunAsc(@A[L], R - L));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortA(@A[L], Pred(Len), RunLen);
            RunLen := Len;
          end;
        ts.PushRun(L, RunLen);
        L += RunLen;
        ts.CollapseA;
      until L > R;
      ts.ForceCollapseA;
    end
  else
    InsertSortA(A, R, Succ(CountRunAsc(A, R)));
end;

class procedure TGBaseTimSort.TTimSort.SortDesc(A: PItem; R: SizeInt);
var
  RunLen, MinLen, Len, L: SizeInt;
  ts: TTimSort;
begin
  if R >= MIN_MERGE_LEN shl 1 then
    begin
      ts.Init(A);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunDesc(@A[L], R - L));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortD(@A[L], Pred(Len), RunLen);
            RunLen := Len;
          end;
        ts.PushRun(L, RunLen);
        L += RunLen;
        ts.CollapseD;
      until L > R;
      ts.ForceCollapseD;
    end
  else
    InsertSortD(A, R, Succ(CountRunDesc(A, R)));
end;

{ TGBaseTimSort }

class procedure TGBaseTimSort.Sort(var A: array of T; aOrder: TSortOrder);
var
  R: SizeInt;
begin
  R := High(A);
  if R > 0 then
    if aOrder = soAsc then
      TTimSort.SortAsc(@A[0], R)
    else
      TTimSort.SortDesc(@A[0], R);
end;

{ TGComparableTimSort.TTimSort }

procedure TGComparableTimSort.TTimSort.CollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtA(I);
    end;
end;

procedure TGComparableTimSort.TTimSort.CollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtD(I);
    end;
end;

procedure TGComparableTimSort.TTimSort.ForceCollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtA(I - 1)
      else
        MergeAtA(I);
    end;
end;

procedure TGComparableTimSort.TTimSort.ForceCollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtD(I - 1)
      else
        MergeAtD(I);
    end;
end;

procedure TGComparableTimSort.TTimSort.MergeAtA(aIndex: SizeInt);
var
  Base1, Len1, Base2, Len2, D: SizeInt;
begin
  Base1 := FStack[aIndex].Base;
  Len1 := FStack[aIndex].Count;
  Base2 := FStack[aIndex + 1].Base;
  Len2 := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := Len1 + Len2;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if FData[Base2] < FData[Pred(Base2)] then
    begin
      D := GallopRightA(FData, FData[Base2], Base1, Len1, 0);
      Base1 += D;
      Len1 -= D;
      if Len1 > 0 then
        if not (FData[Pred(Base2 + Len2)] < FData[Base1]) then
          begin
            Len2 := GallopLeftA(FData, FData[Pred(Base1 + Len1)], Base2, Len2, Len2 - 1);
            if Len2 > 0 then
              if Len1 <= Len2 then
                MergeLoA(Base1, Len1, Base2, Len2)
              else
                MergeHiA(Base1, Len1, Base2, Len2);
          end
        else
          Swap(Base1, Len1, Base2, Len2);
    end;
end;

procedure TGComparableTimSort.TTimSort.MergeAtD(aIndex: SizeInt);
var
  Base1, Len1, Base2, Len2, D: SizeInt;
begin
  Base1 := FStack[aIndex].Base;
  Len1 := FStack[aIndex].Count;
  Base2 := FStack[aIndex + 1].Base;
  Len2 := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := Len1 + Len2;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if FData[Pred(Base2)] < FData[Base2] then
    begin
      D := GallopRightD(FData, FData[Base2], Base1, Len1, 0);
      Base1 += D;
      Len1 -= D;
      if Len1 > 0 then
        if not(FData[Base1] < FData[Pred(Base2 + Len2)]) then
          begin
            Len2 := GallopLeftD(FData, FData[Pred(Base1 + Len1)], Base2, Len2, Len2 - 1);
            if Len2 > 0 then
              if Len1 <= Len2 then
                MergeLoD(Base1, Len1, Base2, Len2)
              else
                MergeHiD(Base1, Len1, Base2, Len2);
          end
        else
          Swap(Base1, Len1, Base2, Len2);
    end;
end;

function TGComparableTimSort.TTimSort.GallopLeftA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
begin
  Dist := 0;
  Result := 1;
  if A[Base + Hint] < Key then
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and (A[Base + Hint + Result] < Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then  //
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end
  else
    begin
      MaxDist := Hint + 1;
      while (Result < MaxDist) and not(A[Base + Hint - Result] < Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then   //
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if A[Base + M] < Key then
        Dist := Succ(M)
      else
        Result := M;
    end;
end;

function TGComparableTimSort.TTimSort.GallopLeftD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
begin
  Dist := 0;
  Result := 1;
  if Key < A[Base + Hint] then
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and (Key < A[Base + Hint + Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then  //
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end
  else
    begin
      MaxDist := Hint + 1;
      while (Result < MaxDist) and not(Key < A[Base + Hint - Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then   //
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if Key < A[Base + M] then
        Dist := Succ(M)
      else
        Result := M;
    end;
end;

function TGComparableTimSort.TTimSort.GallopRightA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
begin
  Dist := 0;
  Result := 1;
  if Key < A[Base + Hint] then
    begin
      MaxDist := Succ(Hint);
      while (Result < MaxDist) and (Key < A[Base + Hint - Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end
  else
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and not(Key < A[Base + Hint + Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if Key < A[Base + M] then
        Result := M
      else
        Dist := Succ(M);
    end;
end;

function TGComparableTimSort.TTimSort.GallopRightD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
begin
  Dist := 0;
  Result := 1;
  if A[Base + Hint] < Key then
    begin
      MaxDist := Succ(Hint);
      while (Result < MaxDist) and (A[Base + Hint - Result] < Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end
  else
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and not(A[Base + Hint + Result] < Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if A[Base + M] < Key then
        Result := M
      else
        Dist := Succ(M);
    end;
end;

procedure TGComparableTimSort.TTimSort.MergeLoA(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in buffer)
  pHi,             // position in high part  (in data array)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data
  LocB: PItem;     // local pointer to buffer
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len1);
  System.Move(LocA[Base1], LocB[0], Len1 * SizeOf(T));
  pLo := 0;
  pHi := Base2;
  pDst := Base1;
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if not(LocA[pHi] < LocB[pLo]) then
        begin
          TFake(LocA[pDst]) := TFake(LocB[pLo]);
          Inc(pDst);
          Inc(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocA[pHi]);
          Inc(pDst);
          Inc(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := GallopRightA(@LocB[0], LocA[pHi], pLo, Len1, 0);
      if Count1 <> 0 then
        begin
          System.Move(LocB[pLo], LocA[pDst], Count1 * SizeOf(T));
          Len1 -= Count1;
          pDst += Count1;
          pLo += Count1;
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pHi]);
      Dec(Len2);
      Inc(pDst);
      Inc(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := GallopLeftA(LocA, LocB[pLo], pHi, Len2, 0);
      if Count2 <> 0 then
        begin
          System.Move(LocA[pHi], LocA[pDst], Count2 * SizeOf(T));
          Len2 -= Count2;
          pDst += Count2;
          pHi += Count2;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pLo]);
      Dec(Len1);
      Inc(pDst);
      Inc(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len1 > 0 then
    System.Move(LocB[pLo], LocA[pDst], Len1 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGComparableTimSort.TTimSort.MergeLoD(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in buffer)
  pHi,             // position in high part  (in data array)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data
  LocB: PItem;     // local pointer to buffer
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len1);
  System.Move(LocA[Base1], LocB[0], Len1 * SizeOf(T));
  pLo := 0;
  pHi := Base2;
  pDst := Base1;
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if not(LocB[pLo] < LocA[pHi]) then
        begin
          TFake(LocA[pDst]) := TFake(LocB[pLo]);
          Inc(pDst);
          Inc(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocA[pHi]);
          Inc(pDst);
          Inc(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := GallopRightD(@LocB[0], LocA[pHi], pLo, Len1, 0);
      if Count1 <> 0 then
        begin
          System.Move(LocB[pLo], LocA[pDst], Count1 * SizeOf(T));
          Len1 -= Count1;
          pDst += Count1;
          pLo += Count1;
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pHi]);
      Dec(Len2);
      Inc(pDst);
      Inc(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := GallopLeftD(LocA, LocB[pLo], pHi, Len2, 0);
      if Count2 <> 0 then
        begin
          System.Move(LocA[pHi], LocA[pDst], Count2 * SizeOf(T));
          Len2 -= Count2;
          pDst += Count2;
          pHi += Count2;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pLo]);
      Dec(Len1);
      Inc(pDst);
      Inc(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len1 > 0 then
    System.Move(LocB[pLo], LocA[pDst], Len1 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGComparableTimSort.TTimSort.MergeHiA(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in data array)
  pHi,             // position in high part  (in buffer)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data array
  LocB: PItem;     // local pointer to buffer
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len2);
  System.Move(LocA[Base2], LocB[0], Len2 * SizeOf(T));
  pLo := Pred(Base1 + Len1);
  pHi := Pred(Len2);
  pDst := Pred(Base2 + Len2);
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if LocB[pHi] < LocA[pLo] then
        begin
          TFake(LocA[pDst]) := TFake(LocA[pLo]);
          Dec(pDst);
          Dec(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocB[pHi]);
          Dec(pDst);
          Dec(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := Len1 - GallopRightA(LocA, LocB[pHi], Base1, Len1, Pred(Len1));
      if Count1 <> 0 then
        begin
          Len1 -= Count1;
          pDst -= Count1;
          pLo -= Count1;
          System.Move(LocA[Succ(pLo)], LocA[Succ(pDst)], Count1 * SizeOf(T));
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pHi]);
      Dec(Len2);
      Dec(pDst);
      Dec(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := Len2 - GallopLeftA(@LocB[0], LocA[pLo], 0, Len2, Pred(Len2));
      if Count2 <> 0 then
        begin
          Len2 -= Count2;
          pDst -= Count2;
          pHi -= Count2;
          System.Move(LocB[Succ(pHi)], LocA[Succ(pDst)], Count2 * SizeOf(T));
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pLo]);
      Dec(Len1);
      Dec(pDst);
      Dec(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len2 > 0 then
    System.Move(LocB[0], LocA[Succ(pDst - Len2)], Len2 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGComparableTimSort.TTimSort.MergeHiD(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in data array)
  pHi,             // position in high part  (in buffer)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data array
  LocB: PItem;     // local pointer to buffer
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len2);
  System.Move(LocA[Base2], LocB[0], Len2 * SizeOf(T));
  pLo := Pred(Base1 + Len1);
  pHi := Pred(Len2);
  pDst := Pred(Base2 + Len2);
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if LocA[pLo] < LocB[pHi] then
        begin
          TFake(LocA[pDst]) := TFake(LocA[pLo]);
          Dec(pDst);
          Dec(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocB[pHi]);
          Dec(pDst);
          Dec(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := Len1 - GallopRightD(LocA, LocB[pHi], Base1, Len1, Pred(Len1));
      if Count1 <> 0 then
        begin
          Len1 -= Count1;
          pDst -= Count1;
          pLo -= Count1;
          System.Move(LocA[Succ(pLo)], LocA[Succ(pDst)], Count1 * SizeOf(T));
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pHi]);
      Dec(Len2);
      Dec(pDst);
      Dec(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := Len2 - GallopLeftD(@LocB[0], LocA[pLo], 0, Len2, Pred(Len2));
      if Count2 <> 0 then
        begin
          Len2 -= Count2;
          pDst -= Count2;
          pHi -= Count2;
          System.Move(LocB[Succ(pHi)], LocA[Succ(pDst)], Count2 * SizeOf(T));
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pLo]);
      Dec(Len1);
      Dec(pDst);
      Dec(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len2 > 0 then
    System.Move(LocB[0], LocA[Succ(pDst - Len2)], Len2 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

class procedure TGComparableTimSort.TTimSort.InsertSortA(A: PItem; R, At: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and (T(v) < A[J]) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class procedure TGComparableTimSort.TTimSort.InsertSortD(A: PItem; R, At: SizeInt);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and (A[J] < T(v)) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class function TGComparableTimSort.TTimSort.CountRunAsc(A: PItem; R: SizeInt): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not(A[1] < A[0]) then// ascending
        while (Result < R) and not(A[Succ(Result)] < A[Result]) do
          Inc(Result)
      else                    // descending
        begin
          while (Result < R) and (A[Succ(Result)] < A[Result]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class function TGComparableTimSort.TTimSort.CountRunDesc(A: PItem; R: SizeInt): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not(A[0] < A[1]) then// descending
        while (Result < R) and not(A[Result] < A[Succ(Result)]) do
          Inc(Result)
      else                    // ascending
        begin
          while (Result < R) and (A[Result] < A[Succ(Result)]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class procedure TGComparableTimSort.TTimSort.SortAsc(A: PItem; R: SizeInt);
var
  RunLen, MinLen, Len, L: SizeInt;
  ts: TTimSort;
begin
  if R >= MIN_MERGE_LEN shl 1 then
    begin
      ts.Init(A);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunAsc(@A[L], R - L));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortA(@A[L], Pred(Len), RunLen);
            RunLen := Len;
          end;
        ts.PushRun(L, RunLen);
        L += RunLen;
        ts.CollapseA;
      until L > R;
      ts.ForceCollapseA;
    end
  else
    InsertSortA(A, R, Succ(CountRunAsc(A, R)));
end;

class procedure TGComparableTimSort.TTimSort.SortDesc(A: PItem; R: SizeInt);
var
  RunLen, MinLen, Len, L: SizeInt;
  ts: TTimSort;
begin
  if R >= MIN_MERGE_LEN shl 1 then
    begin
      ts.Init(A);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunDesc(@A[L], R - L));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortD(@A[L], Pred(Len), RunLen);
            RunLen := Len;
          end;
        ts.PushRun(L, RunLen);
        L += RunLen;
        ts.CollapseD;
      until L > R;
      ts.ForceCollapseD;
    end
  else
    InsertSortD(A, R, Succ(CountRunDesc(A, R)));
end;

{ TGComparableTimSort }

class procedure TGComparableTimSort.Sort(var A: array of T; aOrder: TSortOrder);
var
  R: SizeInt;
begin
  R := High(A);
  if R > 0 then
    if aOrder = soAsc then
      TTimSort.SortAsc(@A[0], R)
    else
      TTimSort.SortDesc(@A[0], R);
end;

{ TGRegularTimSort.TTimSort }

procedure TGRegularTimSort.TTimSort.Init(A: PItem; c: TLess);
begin
  inherited Init(A);
  FLess := c;
end;

procedure TGRegularTimSort.TTimSort.CollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtA(I);
    end;
end;

procedure TGRegularTimSort.TTimSort.CollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtD(I);
    end;
end;

procedure TGRegularTimSort.TTimSort.ForceCollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtA(I - 1)
      else
        MergeAtA(I);
    end;
end;

procedure TGRegularTimSort.TTimSort.ForceCollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtD(I - 1)
      else
        MergeAtD(I);
    end;
end;

procedure TGRegularTimSort.TTimSort.MergeAtA(aIndex: SizeInt);
var
  Base1, Len1, Base2, Len2, Dist: SizeInt;
begin
  Base1 := FStack[aIndex].Base;
  Len1 := FStack[aIndex].Count;
  Base2 := FStack[aIndex + 1].Base;
  Len2 := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := Len1 + Len2;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if FLess(FData[Base2], FData[Pred(Base2)]) then
    begin
      Dist := GallopRightA(FData, FData[Base2], Base1, Len1, 0);
      Base1 += Dist;
      Len1 -= Dist;
      if Len1 > 0 then
        if not FLess(FData[Pred(Base2 + Len2)], FData[Base1]) then
          begin
            Len2 := GallopLeftA(FData, FData[Pred(Base1 + Len1)], Base2, Len2, Len2 - 1);
            if Len2 > 0 then
              if Len1 <= Len2 then
                MergeLoA(Base1, Len1, Base2, Len2)
              else
                MergeHiA(Base1, Len1, Base2, Len2);
          end
        else
          Swap(Base1, Len1, Base2, Len2);
    end;
end;

procedure TGRegularTimSort.TTimSort.MergeAtD(aIndex: SizeInt);
var
  Base1, Len1, Base2, Len2, Dist: SizeInt;
begin
  Base1 := FStack[aIndex].Base;
  Len1 := FStack[aIndex].Count;
  Base2 := FStack[aIndex + 1].Base;
  Len2 := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := Len1 + Len2;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if FLess(FData[Pred(Base2)], FData[Base2]) then
    begin
      Dist := GallopRightD(FData, FData[Base2], Base1, Len1, 0);
      Base1 += Dist;
      Len1 -= Dist;
      if Len1 > 0 then
        if not FLess(FData[Base1], FData[Pred(Base2 + Len2)]) then
          begin
            Len2 := GallopLeftD(FData, FData[Pred(Base1 + Len1)], Base2, Len2, Len2 - 1);
            if Len2 > 0 then
              if Len1 <= Len2 then
                MergeLoD(Base1, Len1, Base2, Len2)
              else
                MergeHiD(Base1, Len1, Base2, Len2);
          end
        else
          Swap(Base1, Len1, Base2, Len2);
    end;
end;

function TGRegularTimSort.TTimSort.GallopLeftA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(A[Base + Hint], Key) then
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and c(A[Base + Hint + Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then  //
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end
  else
    begin
      MaxDist := Hint + 1;
      while (Result < MaxDist) and not c(A[Base + Hint - Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then   //
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(A[Base + M], Key) then
        Dist := Succ(M)
      else
        Result := M;
    end;
end;

function TGRegularTimSort.TTimSort.GallopLeftD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(Key, A[Base + Hint]) then
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and c(Key, A[Base + Hint + Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then  //
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end
  else
    begin
      MaxDist := Hint + 1;
      while (Result < MaxDist) and not c(Key, A[Base + Hint - Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then   //
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(Key, A[Base + M]) then
        Dist := Succ(M)
      else
        Result := M;
    end;
end;

function TGRegularTimSort.TTimSort.GallopRightA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(Key, A[Base + Hint]) then
    begin
      MaxDist := Succ(Hint);
      while (Result < MaxDist) and c(Key, A[Base + Hint - Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end
  else
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and not c(Key, A[Base + Hint + Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(Key, A[Base + M]) then
        Result := M
      else
        Dist := Succ(M);
    end;
end;

function TGRegularTimSort.TTimSort.GallopRightD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(A[Base + Hint], Key) then
    begin
      MaxDist := Succ(Hint);
      while (Result < MaxDist) and c(A[Base + Hint - Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end
  else
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and not c(A[Base + Hint + Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(A[Base + M], Key) then
        Result := M
      else
        Dist := Succ(M);
    end;
end;

procedure TGRegularTimSort.TTimSort.MergeLoA(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in buffer)
  pHi,             // position in high part  (in data array)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data
  LocB: PItem;     // local pointer to buffer
  c: TLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len1);
  c := FLess;
  System.Move(LocA[Base1], LocB[0], Len1 * SizeOf(T));
  pLo := 0;
  pHi := Base2;
  pDst := Base1;
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if not c(LocA[pHi], LocB[pLo]) then
        begin
          TFake(LocA[pDst]) := TFake(LocB[pLo]);
          Inc(pDst);
          Inc(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocA[pHi]);
          Inc(pDst);
          Inc(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := GallopRightA(@LocB[0], LocA[pHi], pLo, Len1, 0);
      if Count1 <> 0 then
        begin
          System.Move(LocB[pLo], LocA[pDst], Count1 * SizeOf(T));
          Len1 -= Count1;
          pDst += Count1;
          pLo += Count1;
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pHi]);
      Dec(Len2);
      Inc(pDst);
      Inc(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := GallopLeftA(LocA, LocB[pLo], pHi, Len2, 0);
      if Count2 <> 0 then
        begin
          System.Move(LocA[pHi], LocA[pDst], Count2 * SizeOf(T));
          Len2 -= Count2;
          pDst += Count2;
          pHi += Count2;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pLo]);
      Dec(Len1);
      Inc(pDst);
      Inc(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len1 > 0 then
    System.Move(LocB[pLo], LocA[pDst], Len1 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGRegularTimSort.TTimSort.MergeLoD(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in buffer)
  pHi,             // position in high part  (in data array)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data
  LocB: PItem;     // local pointer to buffer
  c: TLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len1);
  c := FLess;
  System.Move(LocA[Base1], LocB[0], Len1 * SizeOf(T));
  pLo := 0;
  pHi := Base2;
  pDst := Base1;
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if not c(LocB[pLo], LocA[pHi]) then
        begin
          TFake(LocA[pDst]) := TFake(LocB[pLo]);
          Inc(pDst);
          Inc(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocA[pHi]);
          Inc(pDst);
          Inc(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := GallopRightD(@LocB[0], LocA[pHi], pLo, Len1, 0);
      if Count1 <> 0 then
        begin
          System.Move(LocB[pLo], LocA[pDst], Count1 * SizeOf(T));
          Len1 -= Count1;
          pDst += Count1;
          pLo += Count1;
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pHi]);
      Dec(Len2);
      Inc(pDst);
      Inc(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := GallopLeftD(LocA, LocB[pLo], pHi, Len2, 0);
      if Count2 <> 0 then
        begin
          System.Move(LocA[pHi], LocA[pDst], Count2 * SizeOf(T));
          Len2 -= Count2;
          pDst += Count2;
          pHi += Count2;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pLo]);
      Dec(Len1);
      Inc(pDst);
      Inc(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len1 > 0 then
    System.Move(LocB[pLo], LocA[pDst], Len1 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGRegularTimSort.TTimSort.MergeHiA(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in data array)
  pHi,             // position in high part  (in buffer)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data array
  LocB: PItem;     // local pointer to buffer
  c: TLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len2);
  c := FLess;
  System.Move(LocA[Base2], LocB[0], Len2 * SizeOf(T));
  pLo := Pred(Base1 + Len1);
  pHi := Pred(Len2);
  pDst := Pred(Base2 + Len2);
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if c(LocB[pHi], LocA[pLo]) then
        begin
          TFake(LocA[pDst]) := TFake(LocA[pLo]);
          Dec(pDst);
          Dec(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocB[pHi]);
          Dec(pDst);
          Dec(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := Len1 - GallopRightA(LocA, LocB[pHi], Base1, Len1, Pred(Len1));
      if Count1 <> 0 then
        begin
          Len1 -= Count1;
          pDst -= Count1;
          pLo -= Count1;
          System.Move(LocA[Succ(pLo)], LocA[Succ(pDst)], Count1 * SizeOf(T));
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pHi]);
      Dec(Len2);
      Dec(pDst);
      Dec(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := Len2 - GallopLeftA(@LocB[0], LocA[pLo], 0, Len2, Pred(Len2));
      if Count2 <> 0 then
        begin
          Len2 -= Count2;
          pDst -= Count2;
          pHi -= Count2;
          System.Move(LocB[Succ(pHi)], LocA[Succ(pDst)], Count2 * SizeOf(T));
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pLo]);
      Dec(Len1);
      Dec(pDst);
      Dec(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len2 > 0 then
    System.Move(LocB[0], LocA[Succ(pDst - Len2)], Len2 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGRegularTimSort.TTimSort.MergeHiD(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in data array)
  pHi,             // position in high part  (in buffer)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data array
  LocB: PItem;     // local pointer to buffer
  c: TLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len2);
  c := FLess;
  System.Move(LocA[Base2], LocB[0], Len2 * SizeOf(T));
  pLo := Pred(Base1 + Len1);
  pHi := Pred(Len2);
  pDst := Pred(Base2 + Len2);
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if c(LocA[pLo], LocB[pHi]) then
        begin
          TFake(LocA[pDst]) := TFake(LocA[pLo]);
          Dec(pDst);
          Dec(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocB[pHi]);
          Dec(pDst);
          Dec(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := Len1 - GallopRightD(LocA, LocB[pHi], Base1, Len1, Pred(Len1));
      if Count1 <> 0 then
        begin
          Len1 -= Count1;
          pDst -= Count1;
          pLo -= Count1;
          System.Move(LocA[Succ(pLo)], LocA[Succ(pDst)], Count1 * SizeOf(T));
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pHi]);
      Dec(Len2);
      Dec(pDst);
      Dec(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := Len2 - GallopLeftD(@LocB[0], LocA[pLo], 0, Len2, Pred(Len2));
      if Count2 <> 0 then
        begin
          Len2 -= Count2;
          pDst -= Count2;
          pHi -= Count2;
          System.Move(LocB[Succ(pHi)], LocA[Succ(pDst)], Count2 * SizeOf(T));
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pLo]);
      Dec(Len1);
      Dec(pDst);
      Dec(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len2 > 0 then
    System.Move(LocB[0], LocA[Succ(pDst - Len2)], Len2 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

class procedure TGRegularTimSort.TTimSort.InsertSortA(A: PItem; R, At: SizeInt; c: TLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(T(v), A[J]) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class procedure TGRegularTimSort.TTimSort.InsertSortD(A: PItem; R, At: SizeInt; c: TLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(A[J], T(v)) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class function TGRegularTimSort.TTimSort.CountRunAsc(A: PItem; R: SizeInt; c: TLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[1], A[0]) then  // ascending
        while (Result < R) and not c(A[Succ(Result)], A[Result]) do
          Inc(Result)
      else                       // descending
        begin
          while (Result < R) and c(A[Succ(Result)], A[Result]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class function TGRegularTimSort.TTimSort.CountRunDesc(A: PItem; R: SizeInt; c: TLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[0], A[1]) then  // descending
        while (Result < R) and not c(A[Result], A[Succ(Result)]) do
          Inc(Result)
      else                       // ascending
        begin
          while (Result < R) and c(A[Result], A[Succ(Result)]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class procedure TGRegularTimSort.TTimSort.SortAsc(A: PItem; R: SizeInt; c: TLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ts: TTimSort;
begin
  if R >= MIN_MERGE_LEN shl 1 then
    begin
      ts.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunAsc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortA(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ts.PushRun(L, RunLen);
        L += RunLen;
        ts.CollapseA;
      until L > R;
      ts.ForceCollapseA;
    end
  else
    InsertSortA(A, R, Succ(CountRunAsc(A, R, c)), c);
end;

class procedure TGRegularTimSort.TTimSort.SortDesc(A: PItem; R: SizeInt; c: TLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ts: TTimSort;
begin
  if R >= MIN_MERGE_LEN shl 1 then
    begin
      ts.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunDesc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortD(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ts.PushRun(L, RunLen);
        L += RunLen;
        ts.CollapseD;
      until L > R;
      ts.ForceCollapseD;
    end
  else
    InsertSortD(A, R, Succ(CountRunDesc(A, R, c)), c);
end;

{ TGRegularTimSort }

class procedure TGRegularTimSort.Sort(var A: array of T; c: TLess; aOrder: TSortOrder);
var
  R: SizeInt;
begin
  R := High(A);
  if R > 0 then
    if aOrder = soAsc then
      TTimSort.SortAsc(@A[0], R, c)
    else
      TTimSort.SortDesc(@A[0], R, c);
end;

{ TGDelegatedTimSort.TTimSort }

procedure TGDelegatedTimSort.TTimSort.Init(A: PItem; c: TOnLess);
begin
  inherited Init(A);
  FLess := c;
end;

procedure TGDelegatedTimSort.TTimSort.CollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtA(I);
    end;
end;

procedure TGDelegatedTimSort.TTimSort.CollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtD(I);
    end;
end;

procedure TGDelegatedTimSort.TTimSort.ForceCollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtA(I - 1)
      else
        MergeAtA(I);
    end;
end;

procedure TGDelegatedTimSort.TTimSort.ForceCollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtD(I - 1)
      else
        MergeAtD(I);
    end;
end;

procedure TGDelegatedTimSort.TTimSort.MergeAtA(aIndex: SizeInt);
var
  Base1, Len1, Base2, Len2, Dist: SizeInt;
begin
  Base1 := FStack[aIndex].Base;
  Len1 := FStack[aIndex].Count;
  Base2 := FStack[aIndex + 1].Base;
  Len2 := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := Len1 + Len2;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if FLess(FData[Base2], FData[Pred(Base2)]) then
    begin
      Dist := GallopRightA(FData, FData[Base2], Base1, Len1, 0);
      Base1 += Dist;
      Len1 -= Dist;
      if Len1 > 0 then
        if not FLess(FData[Pred(Base2 + Len2)], FData[Base1]) then
          begin
            Len2 := GallopLeftA(FData, FData[Pred(Base1 + Len1)], Base2, Len2, Len2 - 1);
            if Len2 > 0 then
              if Len1 <= Len2 then
                MergeLoA(Base1, Len1, Base2, Len2)
              else
                MergeHiA(Base1, Len1, Base2, Len2);
          end
        else
          Swap(Base1, Len1, Base2, Len2);
    end;
end;

procedure TGDelegatedTimSort.TTimSort.MergeAtD(aIndex: SizeInt);
var
  Base1, Len1, Base2, Len2, Dist: SizeInt;
begin
  Base1 := FStack[aIndex].Base;
  Len1 := FStack[aIndex].Count;
  Base2 := FStack[aIndex + 1].Base;
  Len2 := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := Len1 + Len2;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if FLess(FData[Pred(Base2)], FData[Base2]) then
    begin
      Dist := GallopRightD(FData, FData[Base2], Base1, Len1, 0);
      Base1 += Dist;
      Len1 -= Dist;
      if Len1 > 0 then
        if not FLess(FData[Base1], FData[Pred(Base2 + Len2)]) then
          begin
            Len2 := GallopLeftD(FData, FData[Pred(Base1 + Len1)], Base2, Len2, Len2 - 1);
            if Len2 > 0 then
              if Len1 <= Len2 then
                MergeLoD(Base1, Len1, Base2, Len2)
              else
                MergeHiD(Base1, Len1, Base2, Len2);
          end
        else
          Swap(Base1, Len1, Base2, Len2);
    end;
end;

function TGDelegatedTimSort.TTimSort.GallopLeftA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TOnLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(A[Base + Hint], Key) then
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and c(A[Base + Hint + Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then  //
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end
  else
    begin
      MaxDist := Hint + 1;
      while (Result < MaxDist) and not c(A[Base + Hint - Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then   //
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(A[Base + M], Key) then
        Dist := Succ(M)
      else
        Result := M;
    end;
end;

function TGDelegatedTimSort.TTimSort.GallopLeftD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TOnLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(Key, A[Base + Hint]) then
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and c(Key, A[Base + Hint + Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then  //
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end
  else
    begin
      MaxDist := Hint + 1;
      while (Result < MaxDist) and not c(Key, A[Base + Hint - Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then   //
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(Key, A[Base + M]) then
        Dist := Succ(M)
      else
        Result := M;
    end;
end;

function TGDelegatedTimSort.TTimSort.GallopRightA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TOnLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(Key, A[Base + Hint]) then
    begin
      MaxDist := Succ(Hint);
      while (Result < MaxDist) and c(Key, A[Base + Hint - Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end
  else
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and not c(Key, A[Base + Hint + Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(Key, A[Base + M]) then
        Result := M
      else
        Dist := Succ(M);
    end;
end;

function TGDelegatedTimSort.TTimSort.GallopRightD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TOnLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(A[Base + Hint], Key) then
    begin
      MaxDist := Succ(Hint);
      while (Result < MaxDist) and c(A[Base + Hint - Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end
  else
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and not c(A[Base + Hint + Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(A[Base + M], Key) then
        Result := M
      else
        Dist := Succ(M);
    end;
end;

procedure TGDelegatedTimSort.TTimSort.MergeLoA(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in buffer)
  pHi,             // position in high part  (in data array)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data
  LocB: PItem;     // local pointer to buffer
  c: TOnLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len1);
  c := FLess;
  System.Move(LocA[Base1], LocB[0], Len1 * SizeOf(T));
  pLo := 0;
  pHi := Base2;
  pDst := Base1;
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if not c(LocA[pHi], LocB[pLo]) then
        begin
          TFake(LocA[pDst]) := TFake(LocB[pLo]);
          Inc(pDst);
          Inc(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocA[pHi]);
          Inc(pDst);
          Inc(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := GallopRightA(@LocB[0], LocA[pHi], pLo, Len1, 0);
      if Count1 <> 0 then
        begin
          System.Move(LocB[pLo], LocA[pDst], Count1 * SizeOf(T));
          Len1 -= Count1;
          pDst += Count1;
          pLo += Count1;
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pHi]);
      Dec(Len2);
      Inc(pDst);
      Inc(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := GallopLeftA(LocA, LocB[pLo], pHi, Len2, 0);
      if Count2 <> 0 then
        begin
          System.Move(LocA[pHi], LocA[pDst], Count2 * SizeOf(T));
          Len2 -= Count2;
          pDst += Count2;
          pHi += Count2;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pLo]);
      Dec(Len1);
      Inc(pDst);
      Inc(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len1 > 0 then
    System.Move(LocB[pLo], LocA[pDst], Len1 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGDelegatedTimSort.TTimSort.MergeLoD(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in buffer)
  pHi,             // position in high part  (in data array)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data
  LocB: PItem;     // local pointer to buffer
  c: TOnLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len1);
  c := FLess;
  System.Move(LocA[Base1], LocB[0], Len1 * SizeOf(T));
  pLo := 0;
  pHi := Base2;
  pDst := Base1;
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if not c(LocB[pLo], LocA[pHi]) then
        begin
          TFake(LocA[pDst]) := TFake(LocB[pLo]);
          Inc(pDst);
          Inc(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocA[pHi]);
          Inc(pDst);
          Inc(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := GallopRightD(@LocB[0], LocA[pHi], pLo, Len1, 0);
      if Count1 <> 0 then
        begin
          System.Move(LocB[pLo], LocA[pDst], Count1 * SizeOf(T));
          Len1 -= Count1;
          pDst += Count1;
          pLo += Count1;
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pHi]);
      Dec(Len2);
      Inc(pDst);
      Inc(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := GallopLeftD(LocA, LocB[pLo], pHi, Len2, 0);
      if Count2 <> 0 then
        begin
          System.Move(LocA[pHi], LocA[pDst], Count2 * SizeOf(T));
          Len2 -= Count2;
          pDst += Count2;
          pHi += Count2;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pLo]);
      Dec(Len1);
      Inc(pDst);
      Inc(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len1 > 0 then
    System.Move(LocB[pLo], LocA[pDst], Len1 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGDelegatedTimSort.TTimSort.MergeHiA(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in data array)
  pHi,             // position in high part  (in buffer)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data array
  LocB: PItem;     // local pointer to buffer
  c: TOnLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len2);
  c := FLess;
  System.Move(LocA[Base2], LocB[0], Len2 * SizeOf(T));
  pLo := Pred(Base1 + Len1);
  pHi := Pred(Len2);
  pDst := Pred(Base2 + Len2);
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if c(LocB[pHi], LocA[pLo]) then
        begin
          TFake(LocA[pDst]) := TFake(LocA[pLo]);
          Dec(pDst);
          Dec(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocB[pHi]);
          Dec(pDst);
          Dec(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := Len1 - GallopRightA(LocA, LocB[pHi], Base1, Len1, Pred(Len1));
      if Count1 <> 0 then
        begin
          Len1 -= Count1;
          pDst -= Count1;
          pLo -= Count1;
          System.Move(LocA[Succ(pLo)], LocA[Succ(pDst)], Count1 * SizeOf(T));
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pHi]);
      Dec(Len2);
      Dec(pDst);
      Dec(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := Len2 - GallopLeftA(@LocB[0], LocA[pLo], 0, Len2, Pred(Len2));
      if Count2 <> 0 then
        begin
          Len2 -= Count2;
          pDst -= Count2;
          pHi -= Count2;
          System.Move(LocB[Succ(pHi)], LocA[Succ(pDst)], Count2 * SizeOf(T));
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pLo]);
      Dec(Len1);
      Dec(pDst);
      Dec(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len2 > 0 then
    System.Move(LocB[0], LocA[Succ(pDst - Len2)], Len2 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGDelegatedTimSort.TTimSort.MergeHiD(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in data array)
  pHi,             // position in high part  (in buffer)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data array
  LocB: PItem;     // local pointer to buffer
  c: TOnLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len2);
  c := FLess;
  System.Move(LocA[Base2], LocB[0], Len2 * SizeOf(T));
  pLo := Pred(Base1 + Len1);
  pHi := Pred(Len2);
  pDst := Pred(Base2 + Len2);
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if c(LocA[pLo], LocB[pHi]) then
        begin
          TFake(LocA[pDst]) := TFake(LocA[pLo]);
          Dec(pDst);
          Dec(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocB[pHi]);
          Dec(pDst);
          Dec(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := Len1 - GallopRightD(LocA, LocB[pHi], Base1, Len1, Pred(Len1));
      if Count1 <> 0 then
        begin
          Len1 -= Count1;
          pDst -= Count1;
          pLo -= Count1;
          System.Move(LocA[Succ(pLo)], LocA[Succ(pDst)], Count1 * SizeOf(T));
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pHi]);
      Dec(Len2);
      Dec(pDst);
      Dec(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := Len2 - GallopLeftD(@LocB[0], LocA[pLo], 0, Len2, Pred(Len2));
      if Count2 <> 0 then
        begin
          Len2 -= Count2;
          pDst -= Count2;
          pHi -= Count2;
          System.Move(LocB[Succ(pHi)], LocA[Succ(pDst)], Count2 * SizeOf(T));
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pLo]);
      Dec(Len1);
      Dec(pDst);
      Dec(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len2 > 0 then
    System.Move(LocB[0], LocA[Succ(pDst - Len2)], Len2 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

class procedure TGDelegatedTimSort.TTimSort.InsertSortA(A: PItem; R, At: SizeInt; c: TOnLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(T(v), A[J]) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class procedure TGDelegatedTimSort.TTimSort.InsertSortD(A: PItem; R, At: SizeInt; c: TOnLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(A[J], T(v)) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class function TGDelegatedTimSort.TTimSort.CountRunAsc(A: PItem; R: SizeInt; c: TOnLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[1], A[0]) then  // ascending
        while (Result < R) and not c(A[Succ(Result)], A[Result]) do
          Inc(Result)
      else                       // descending
        begin
          while (Result < R) and c(A[Succ(Result)], A[Result]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class function TGDelegatedTimSort.TTimSort.CountRunDesc(A: PItem; R: SizeInt; c: TOnLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[0], A[1]) then  // descending
        while (Result < R) and not c(A[Result], A[Succ(Result)]) do
          Inc(Result)
      else                        // ascending
        begin
          while (Result < R) and c(A[Result], A[Succ(Result)]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class procedure TGDelegatedTimSort.TTimSort.SortAsc(A: PItem; R: SizeInt; c: TOnLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ts: TTimSort;
begin
  if R >= MIN_MERGE_LEN shl 1 then
    begin
      ts.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunAsc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortA(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ts.PushRun(L, RunLen);
        L += RunLen;
        ts.CollapseA;
      until L > R;
      ts.ForceCollapseA;
    end
  else
    InsertSortA(A, R, Succ(CountRunAsc(A, R, c)), c);
end;

class procedure TGDelegatedTimSort.TTimSort.SortDesc(A: PItem; R: SizeInt; c: TOnLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ts: TTimSort;
begin
  if R >= MIN_MERGE_LEN shl 1 then
    begin
      ts.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunDesc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortD(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ts.PushRun(L, RunLen);
        L += RunLen;
        ts.CollapseD;
      until L > R;
      ts.ForceCollapseD;
    end
  else
    InsertSortD(A, R, Succ(CountRunDesc(A, R, c)), c);
end;

{ TGDelegatedTimSort }

class procedure TGDelegatedTimSort.Sort(var A: array of T; c: TOnLess; aOrder: TSortOrder);
var
  R: SizeInt;
begin
  R := High(A);
  if R > 0 then
    if aOrder = soAsc then
      TTimSort.SortAsc(@A[0], R, c)
    else
      TTimSort.SortDesc(@A[0], R, c);
end;

{ TGNestedTimSort.TTimSort }

procedure TGNestedTimSort.TTimSort.Init(A: PItem; c: TNestLess);
begin
  inherited Init(A);
  FLess := c;
end;

procedure TGNestedTimSort.TTimSort.CollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtA(I);
    end;
end;

procedure TGNestedTimSort.TTimSort.CollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count <= FStack[I].Count + FStack[I + 1].Count) then
        begin
          if FStack[I - 1].Count < FStack[I + 1].Count then
            Dec(I);
        end
      else
        if FStack[I].Count > FStack[I + 1].Count then
          break;
      MergeAtD(I);
    end;
end;

procedure TGNestedTimSort.TTimSort.ForceCollapseA;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtA(I - 1)
      else
        MergeAtA(I);
    end;
end;

procedure TGNestedTimSort.TTimSort.ForceCollapseD;
var
  I: SizeInt;
begin
  while FStackCount > 1 do
    begin
      I := FStackCount - 2;
      if (I > 0) and (FStack[I - 1].Count < FStack[I + 1].Count) then
        MergeAtD(I - 1)
      else
        MergeAtD(I);
    end;
end;

procedure TGNestedTimSort.TTimSort.MergeAtA(aIndex: SizeInt);
var
  Base1, Len1, Base2, Len2, Dist: SizeInt;
begin
  Base1 := FStack[aIndex].Base;
  Len1 := FStack[aIndex].Count;
  Base2 := FStack[aIndex + 1].Base;
  Len2 := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := Len1 + Len2;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if FLess(FData[Base2], FData[Pred(Base2)]) then
    begin
      Dist := GallopRightA(FData, FData[Base2], Base1, Len1, 0);
      Base1 += Dist;
      Len1 -= Dist;
      if Len1 > 0 then
        if not FLess(FData[Pred(Base2 + Len2)], FData[Base1]) then
          begin
            Len2 := GallopLeftA(FData, FData[Pred(Base1 + Len1)], Base2, Len2, Len2 - 1);
            if Len2 > 0 then
              if Len1 <= Len2 then
                MergeLoA(Base1, Len1, Base2, Len2)
              else
                MergeHiA(Base1, Len1, Base2, Len2);
          end
        else
          Swap(Base1, Len1, Base2, Len2);
    end;
end;

procedure TGNestedTimSort.TTimSort.MergeAtD(aIndex: SizeInt);
var
  Base1, Len1, Base2, Len2, Dist: SizeInt;
begin
  Base1 := FStack[aIndex].Base;
  Len1 := FStack[aIndex].Count;
  Base2 := FStack[aIndex + 1].Base;
  Len2 := FStack[aIndex + 1].Count;
  FStack[aIndex].Count := Len1 + Len2;
  if aIndex = FStackCount - 3 then
    begin
      FStack[aIndex + 1].Base := FStack[aIndex + 2].Base;
      FStack[aIndex + 1].Count := FStack[aIndex + 2].Count;
    end;
  Dec(FStackCount);
  if FLess(FData[Pred(Base2)], FData[Base2]) then
    begin
      Dist := GallopRightD(FData, FData[Base2], Base1, Len1, 0);
      Base1 += Dist;
      Len1 -= Dist;
      if Len1 > 0 then
        if not FLess(FData[Base1], FData[Pred(Base2 + Len2)]) then
          begin
            Len2 := GallopLeftD(FData, FData[Pred(Base1 + Len1)], Base2, Len2, Len2 - 1);
            if Len2 > 0 then
              if Len1 <= Len2 then
                MergeLoD(Base1, Len1, Base2, Len2)
              else
                MergeHiD(Base1, Len1, Base2, Len2);
          end
        else
          Swap(Base1, Len1, Base2, Len2);
    end;
end;

function TGNestedTimSort.TTimSort.GallopLeftA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TNestLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(A[Base + Hint], Key) then
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and c(A[Base + Hint + Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then  //
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end
  else
    begin
      MaxDist := Hint + 1;
      while (Result < MaxDist) and not c(A[Base + Hint - Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then   //
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(A[Base + M], Key) then
        Dist := Succ(M)
      else
        Result := M;
    end;
end;

function TGNestedTimSort.TTimSort.GallopLeftD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TNestLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(Key, A[Base + Hint]) then
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and c(Key, A[Base + Hint + Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then  //
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end
  else
    begin
      MaxDist := Hint + 1;
      while (Result < MaxDist) and not c(Key, A[Base + Hint - Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then   //
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(Key, A[Base + M]) then
        Dist := Succ(M)
      else
        Result := M;
    end;
end;

function TGNestedTimSort.TTimSort.GallopRightA(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TNestLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(Key, A[Base + Hint]) then
    begin
      MaxDist := Succ(Hint);
      while (Result < MaxDist) and c(Key, A[Base + Hint - Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end
  else
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and not c(Key, A[Base + Hint + Result]) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(Key, A[Base + M]) then
        Result := M
      else
        Dist := Succ(M);
    end;
end;

function TGNestedTimSort.TTimSort.GallopRightD(A: PItem; const Key: T; Base, Len, Hint: SizeInt): SizeInt;
var
  Dist, MaxDist, M: SizeInt;
  c: TNestLess;
begin
  c := FLess;
  Dist := 0;
  Result := 1;
  if c(A[Base + Hint], Key) then
    begin
      MaxDist := Succ(Hint);
      while (Result < MaxDist) and c(A[Base + Hint - Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      M := Dist;
      Dist := Succ(Hint - Math.Min(Result, MaxDist));
      Result := Hint - M;
    end
  else
    begin
      MaxDist := Len - Hint;
      while (Result < MaxDist) and not c(A[Base + Hint + Result], Key) do
        begin
          Dist := Result;
          Result := Succ(Result shl 1);
          if Result <= 0 then
            Result := MaxDist;
        end;
      Result := Math.Min(Result, MaxDist) + Hint;
      Dist += Succ(Hint);
    end;
  while Dist < Result do
    begin
      M := Dist + (Result - Dist) shr 1;
      if c(A[Base + M], Key) then
        Result := M
      else
        Dist := Succ(M);
    end;
end;

procedure TGNestedTimSort.TTimSort.MergeLoA(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in buffer)
  pHi,             // position in high part  (in data array)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data
  LocB: PItem;     // local pointer to buffer
  c: TNestLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len1);
  c := FLess;
  System.Move(LocA[Base1], LocB[0], Len1 * SizeOf(T));
  pLo := 0;
  pHi := Base2;
  pDst := Base1;
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if not c(LocA[pHi], LocB[pLo]) then
        begin
          TFake(LocA[pDst]) := TFake(LocB[pLo]);
          Inc(pDst);
          Inc(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocA[pHi]);
          Inc(pDst);
          Inc(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := GallopRightA(@LocB[0], LocA[pHi], pLo, Len1, 0);
      if Count1 <> 0 then
        begin
          System.Move(LocB[pLo], LocA[pDst], Count1 * SizeOf(T));
          Len1 -= Count1;
          pDst += Count1;
          pLo += Count1;
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pHi]);
      Dec(Len2);
      Inc(pDst);
      Inc(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := GallopLeftA(LocA, LocB[pLo], pHi, Len2, 0);
      if Count2 <> 0 then
        begin
          System.Move(LocA[pHi], LocA[pDst], Count2 * SizeOf(T));
          Len2 -= Count2;
          pDst += Count2;
          pHi += Count2;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pLo]);
      Dec(Len1);
      Inc(pDst);
      Inc(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len1 > 0 then
    System.Move(LocB[pLo], LocA[pDst], Len1 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGNestedTimSort.TTimSort.MergeLoD(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in buffer)
  pHi,             // position in high part  (in data array)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data
  LocB: PItem;     // local pointer to buffer
  c: TNestLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len1);
  c := FLess;
  System.Move(LocA[Base1], LocB[0], Len1 * SizeOf(T));
  pLo := 0;
  pHi := Base2;
  pDst := Base1;
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if not c(LocB[pLo], LocA[pHi]) then
        begin
          TFake(LocA[pDst]) := TFake(LocB[pLo]);
          Inc(pDst);
          Inc(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocA[pHi]);
          Inc(pDst);
          Inc(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := GallopRightD(@LocB[0], LocA[pHi], pLo, Len1, 0);
      if Count1 <> 0 then
        begin
          System.Move(LocB[pLo], LocA[pDst], Count1 * SizeOf(T));
          Len1 -= Count1;
          pDst += Count1;
          pLo += Count1;
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pHi]);
      Dec(Len2);
      Inc(pDst);
      Inc(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := GallopLeftD(LocA, LocB[pLo], pHi, Len2, 0);
      if Count2 <> 0 then
        begin
          System.Move(LocA[pHi], LocA[pDst], Count2 * SizeOf(T));
          Len2 -= Count2;
          pDst += Count2;
          pHi += Count2;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pLo]);
      Dec(Len1);
      Inc(pDst);
      Inc(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len1 > 0 then
    System.Move(LocB[pLo], LocA[pDst], Len1 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGNestedTimSort.TTimSort.MergeHiA(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in data array)
  pHi,             // position in high part  (in buffer)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data array
  LocB: PItem;     // local pointer to buffer
  c: TNestLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len2);
  c := FLess;
  System.Move(LocA[Base2], LocB[0], Len2 * SizeOf(T));
  pLo := Pred(Base1 + Len1);
  pHi := Pred(Len2);
  pDst := Pred(Base2 + Len2);
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if c(LocB[pHi], LocA[pLo]) then
        begin
          TFake(LocA[pDst]) := TFake(LocA[pLo]);
          Dec(pDst);
          Dec(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocB[pHi]);
          Dec(pDst);
          Dec(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := Len1 - GallopRightA(LocA, LocB[pHi], Base1, Len1, Pred(Len1));
      if Count1 <> 0 then
        begin
          Len1 -= Count1;
          pDst -= Count1;
          pLo -= Count1;
          System.Move(LocA[Succ(pLo)], LocA[Succ(pDst)], Count1 * SizeOf(T));
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pHi]);
      Dec(Len2);
      Dec(pDst);
      Dec(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := Len2 - GallopLeftA(@LocB[0], LocA[pLo], 0, Len2, Pred(Len2));
      if Count2 <> 0 then
        begin
          Len2 -= Count2;
          pDst -= Count2;
          pHi -= Count2;
          System.Move(LocB[Succ(pHi)], LocA[Succ(pDst)], Count2 * SizeOf(T));
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pLo]);
      Dec(Len1);
      Dec(pDst);
      Dec(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len2 > 0 then
    System.Move(LocB[0], LocA[Succ(pDst - Len2)], Len2 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

procedure TGNestedTimSort.TTimSort.MergeHiD(Base1, Len1, Base2, Len2: SizeInt);
var
  LocMinGallop,    // local copy FMinGallop
  pLo,             // position in low part   (in data array)
  pHi,             // position in high part  (in buffer)
  pDst,            // current merge position (in data array)
  Count1,          // first run win count
  Count2: SizeInt; // second run win count
  LocA: PItem;     // local pointer to data array
  LocB: PItem;     // local pointer to buffer
  c: TNestLess;
label
  MainLoopDone;
begin
  LocA := FData;
  LocB := EnsureBufferSize(Len2);
  c := FLess;
  System.Move(LocA[Base2], LocB[0], Len2 * SizeOf(T));
  pLo := Pred(Base1 + Len1);
  pHi := Pred(Len2);
  pDst := Pred(Base2 + Len2);
  LocMinGallop := FMinGallop;
  repeat  //MainLoop
    Count1 := 0;
    Count2 := 0;
    repeat
      if c(LocA[pLo], LocB[pHi]) then
        begin
          TFake(LocA[pDst]) := TFake(LocA[pLo]);
          Dec(pDst);
          Dec(pLo);
          Dec(Len1);
          Inc(Count1);
          Count2 := 0;
          if Len1 = 0 then
            goto MainLoopDone;
        end
      else
        begin
          TFake(LocA[pDst]) := TFake(LocB[pHi]);
          Dec(pDst);
          Dec(pHi);
          Dec(Len2);
          Inc(Count2);
          Count1 := 0;
          if Len2 = 0 then
            goto MainLoopDone;
        end;
    until (Count1 or Count2) >= LocMinGallop;
    repeat
      Count1 := Len1 - GallopRightD(LocA, LocB[pHi], Base1, Len1, Pred(Len1));
      if Count1 <> 0 then
        begin
          Len1 -= Count1;
          pDst -= Count1;
          pLo -= Count1;
          System.Move(LocA[Succ(pLo)], LocA[Succ(pDst)], Count1 * SizeOf(T));
          if Len1 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocB[pHi]);
      Dec(Len2);
      Dec(pDst);
      Dec(pHi);
      if Len2 = 0 then
        goto MainLoopDone;
      Count2 := Len2 - GallopLeftD(@LocB[0], LocA[pLo], 0, Len2, Pred(Len2));
      if Count2 <> 0 then
        begin
          Len2 -= Count2;
          pDst -= Count2;
          pHi -= Count2;
          System.Move(LocB[Succ(pHi)], LocA[Succ(pDst)], Count2 * SizeOf(T));
          if Len2 = 0 then
            goto MainLoopDone;
        end;
      TFake(LocA[pDst]) := TFake(LocA[pLo]);
      Dec(Len1);
      Dec(pDst);
      Dec(pLo);
      if Len1 = 0 then
        goto MainLoopDone;
      Dec(LocMinGallop);
    until (Count1 < LocMinGallop) and (Count2 < LocMinGallop);
    if LocMinGallop < 0 then
      LocMinGallop := 0;
    LocMinGallop += 2;
  until False;

MainLoopDone:
  if Len2 > 0 then
    System.Move(LocB[0], LocA[Succ(pDst - Len2)], Len2 * SizeOf(T));
  if LocMinGallop < 1 then
    FMinGallop := 1
  else
    FMinGallop := LocMinGallop;
end;

class procedure TGNestedTimSort.TTimSort.InsertSortA(A: PItem; R, At: SizeInt; c: TNestLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(T(v), A[J]) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class procedure TGNestedTimSort.TTimSort.InsertSortD(A: PItem; R, At: SizeInt; c: TNestLess);
var
  I, J: SizeInt;
  v: TFake;
begin
  if At < 1 then
    At := 1;
  for I := At to R do
    begin
      v := TFake(A[I]);
      J := I - 1;
      while (J >= 0) and c(A[J], T(v)) do
        begin
          TFake(A[J + 1]) := TFake(A[J]);
          Dec(J);
        end;
      TFake(A[J + 1]) := v;
    end;
end;

class function TGNestedTimSort.TTimSort.CountRunAsc(A: PItem; R: SizeInt; c: TNestLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[1], A[0]) then  // ascending
        while (Result < R) and not c(A[Succ(Result)], A[Result]) do
          Inc(Result)
      else                        // descending
        begin
          while (Result < R) and c(A[Succ(Result)], A[Result]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class function TGNestedTimSort.TTimSort.CountRunDesc(A: PItem; R: SizeInt; c: TNestLess): SizeInt;
begin
  if R > 0 then
    begin
      Result := 1;
      if not c(A[0], A[1]) then  // descending
        while (Result < R) and not c(A[Result], A[Succ(Result)]) do
          Inc(Result)
      else                       // ascending
        begin
          while (Result < R) and c(A[Result], A[Succ(Result)]) do
            Inc(Result);
          DoReverse(A, Result);
        end;
    end
  else
    Result := 0;
end;

class procedure TGNestedTimSort.TTimSort.SortAsc(A: PItem; R: SizeInt; c: TNestLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ts: TTimSort;
begin
  if R >= MIN_MERGE_LEN shl 1 then
    begin
      ts.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunAsc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortA(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ts.PushRun(L, RunLen);
        L += RunLen;
        ts.CollapseA;
      until L > R;
      ts.ForceCollapseA;
    end
  else
    InsertSortA(A, R, Succ(CountRunAsc(A, R, c)), c);
end;

class procedure TGNestedTimSort.TTimSort.SortDesc(A: PItem; R: SizeInt; c: TNestLess);
var
  RunLen, MinLen, Len, L: SizeInt;
  ts: TTimSort;
begin
  if R >= MIN_MERGE_LEN shl 1 then
    begin
      ts.Init(A, c);
      MinLen := MinRunLen(R + 1);
      L := 0;
      repeat
        RunLen := Succ(CountRunDesc(@A[L], R - L, c));
        if RunLen < MinLen then
          begin
            Len := Math.Min(Succ(R - L), MinLen);
            InsertSortD(@A[L], Pred(Len), RunLen, c);
            RunLen := Len;
          end;
        ts.PushRun(L, RunLen);
        L += RunLen;
        ts.CollapseD;
      until L > R;
      ts.ForceCollapseD;
    end
  else
    InsertSortD(A, R, Succ(CountRunDesc(A, R, c)), c);
end;

{ TGNestedTimSort }

class procedure TGNestedTimSort.Sort(var A: array of T; c: TNestLess; aOrder: TSortOrder);
var
  R: SizeInt;
begin
  R := High(A);
  if R > 0 then
    if aOrder = soAsc then
      TTimSort.SortAsc(@A[0], R, c)
    else
      TTimSort.SortDesc(@A[0], R, c);
end;

{ TTextFileReader.TEnumerator }

function TTextFileReader.TEnumerator.GetCurrent: string;
begin
  Result := FReader.GetCurrent;
end;

constructor TTextFileReader.TEnumerator.Create(aReader: TTextFileReader);
begin
  FReader := aReader;
end;

function TTextFileReader.TEnumerator.MoveNext: Boolean;
begin
  Result := FReader.MoveNext;
end;

procedure TTextFileReader.TEnumerator.Reset;
begin
  FReader.Reset;
end;

{ TTextFileReader }

procedure TTextFileReader.Close;
begin
  if IsOpen then
    begin
      System.Close(FFile);
      FCurrent := '';
      FFileName := '';
      FExceptClass := '';
      FExceptMsg := '';
      FIsOpen := False;
    end;
end;

function TTextFileReader.GetFile: PText;
begin
  Result := @FFile;
end;

function TTextFileReader.GetCurrent: string;
begin
  Result := FCurrent;
end;

function TTextFileReader.MoveNext: Boolean;
begin
  Result := IsOpen and not System.Eof(FFile);
  if Result then
    System.ReadLn(FFile, FCurrent);
end;

procedure TTextFileReader.Reset;
begin
  if IsOpen then
    System.Reset(FFile);
end;

class function TTextFileReader.FileExists(const aFileName: string): Boolean;
begin
  Result := SysUtils.FileExists(aFileName);
end;

class function TTextFileReader.FileSize(const aFileName: string): Int64;
begin
  try
    with TFileStream.Create(aFileName, fmOpenRead) do
      try
        Result := Size;
      finally
        Free;
      end;
  except
    Result := NULL_INDEX;
  end;
end;

destructor TTextFileReader.Destroy;
begin
  if IsOpen then
    System.Close(FFile);
  inherited;
end;

function TTextFileReader.GetEnumerator: TEnumerator;
begin
  Reset;
  Result := TEnumerator.Create(Self);
end;

{$PUSH}{$IOCHECKS ON}
function TTextFileReader.Open(const aFileName: string): Boolean;
begin
  Close;
  FFileName := aFileName;
  try
    Assign(FFile, FFileName);
    System.Reset(FFile);
    System.SetTextBuf(FFile, FBuffer, SizeOf(FBuffer));
    FIsOpen := True;
  except
    on e: Exception do
      begin
        FExceptClass := e.ClassName;
        FExceptMsg := e.Message;
      end;
  end;
  Result := IsOpen;
end;
{$POP}

function TTextFileReader.LoadText(const aFileName: string; out aText: string): Boolean;
begin
  Result := False;
  try
    with TStringStream.Create do
      try
        LoadFromFile(aFileName);
        aText := DataString;
        Result := True;
      finally
        Free;
      end;
  except
    on e: Exception do
      begin
        FExceptClass := e.ClassName;
        FExceptMsg := e.Message;
      end;
  end;
end;

function TTextFileWriter.IsStandardFile: Boolean;
begin
  Result := True;
  case FFileName.ToLower of
    sOutput, sStdOut: FFile := Stdout;
    sStdErr:          FFile := StdErr;
  else
    Result := False;
  end;
  FIsStandard := Result;
end;

function TTextFileWriter.GetFile: PText;
begin
  Result := @FFile;
end;

{$PUSH}{$IOCHECKS ON}
procedure TTextFileWriter.Open;
begin
  if not IsStandardFile then
    try
      System.Assign(FFile, FFileName);
      System.Rewrite(FFile);
      System.SetTextBuf(FFile, FBuffer, SizeOf(FBuffer));
      FIsOpen := True;
    except
      on e: Exception do
        begin
          FExceptClass := e.ClassName;
          FExceptMsg := e.Message;
        end;
    end
  else
    FIsOpen := True;
end;

procedure TTextFileWriter.AppendFile;
begin
  if not IsStandardFile then
    try
      System.Assign(FFile, FFileName);
      System.Append(FFile);
      System.SetTextBuf(FFile, FBuffer, SizeOf(FBuffer));
      FIsOpen := True;
    except
      on e: Exception do
        begin
          FExceptClass := e.ClassName;
          FExceptMsg := e.Message;
        end;
    end
  else
    FIsOpen := True;
end;
{$POP}

procedure TTextFileWriter.Close;
begin
  if IsOpen then
    begin
      System.Flush(FFile);
      if not IsStandard then
        System.Close(FFile);
      FIsOpen := False;
    end;
end;

constructor TTextFileWriter.Create(const aFileName: string; Append: Boolean);
begin
  inherited Create;
  FFileName := aFileName;
  FAppend := Append;
end;

destructor TTextFileWriter.Destroy;
begin
  Close;
  inherited;
end;

procedure TTextFileWriter.AfterConstruction;
begin
  inherited;
  if FAppend then
    AppendFile
  else
    Open;
end;

function TTextFileWriter.Add(const aValue: string): Boolean;
begin
  Result := IsOpen;
  if Result then
    System.Writeln(FFile, aValue)
end;

function TTextFileWriter.AddAll(const a: array of string): SizeInt;
var
  s: string;
begin
  Result := 0;
  for s in a do
    Result += Ord(Add(s));
end;

function TTextFileWriter.AddAll(e: IStringEnumerable): SizeInt;
var
  s: string;
begin
  Result := 0;
  for s in e do
    Result += Ord(Add(s));
end;

{ TGetEnumerable }

function TGetEnumerable.GetCurrent: T;
begin
  Result := FWorkEnum.Current;
end;

class function TGetEnumerable.Construct(const aEnum: TEnumerator): IEnumerable;
begin
  Result := TGetEnumerable.Create(aEnum);
end;

constructor TGetEnumerable.Create(const aEnum: TEnumerator);
begin
  inherited Create;
  FEnum := aEnum;
  FWorkEnum := aEnum;
end;

function TGetEnumerable.MoveNext: Boolean;
begin
  Result := FWorkEnum.MoveNext;
end;

procedure TGetEnumerable.Reset;
begin
  FWorkEnum := FEnum;
end;

{ TGClassEnumerable }

function TGClassEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current;
end;

class function TGClassEnumerable.Construct(aEntity: TEntity): IEnumerable;
begin
  Result := TGClassEnumerable.Create(aEntity);
end;

constructor TGClassEnumerable.Create(aEntity: TEntity);
begin
  inherited Create;
  FEntity := aEntity;
end;

destructor TGClassEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGClassEnumerable.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGClassEnumerable.Reset;
begin
  FEnum.Free;
  FEnum := FEntity.GetEnumerator;
end;

{ TGBaseLruCache }

function TGBaseLruCache.GetLoadFactor: Single;
begin
  Result := FMap.LoadFactor;
end;

procedure TGBaseLruCache.SetSizeLimit(aValue: SizeInt);
begin
  if FSizeLimit = aValue then exit;
  if aValue < 1 then
    EArgumentException.CreateFmt(SEInputShouldAtLeastFmt, ['aSizeLimit', 1]);
  FSizeLimit := aValue;
  while FMap.Count > SizeLimit do
    FMap.RemoveFirst;
end;

procedure TGBaseLruCache.SetLoadFactor(aValue: Single);
begin
  FMap.LoadFactor := aValue;
end;

constructor TGBaseLruCache.Create(aGetValue: TOnGetValue; aSizeLimit: SizeInt);
begin
  if aGetValue = nil then
    raise EArgumentNilException.Create(SECallbackMissed);
  FGetValue := aGetValue;
  FMap := TMap.Create;
  FMap.UpdateOnHit := True;
  SizeLimit := aSizeLimit;
end;

constructor TGBaseLruCache.Create(aGetValue: TOnGetValue; aSizeLimit: SizeInt; aLoadFactor: Single);
begin
  Create(aGetValue, aSizeLimit);
  FMap.LoadFactor := aLoadFactor;
end;

constructor TGBaseLruCache.Create(aGetValue: TOnGetValue; aSizeLimit, aCapacity: SizeInt; aLoadFactor: Single);
begin
  if aGetValue = nil then
    raise EArgumentNilException.Create(SECallbackMissed);
  FGetValue := aGetValue;
  FMap := TMap.Create(aCapacity, aLoadFactor);
  FMap.UpdateOnHit := True;
  SizeLimit := aSizeLimit;
end;

destructor TGBaseLruCache.Destroy;
begin
  FMap.Free;
  inherited;
end;

procedure TGBaseLruCache.Clear;
begin
  FMap.Clear;
end;

procedure TGBaseLruCache.TrimToFit;
begin
  FMap.TrimToFit;
end;

function TGBaseLruCache.GetValue(const aKey: TKey): TValue;
begin
  if not FMap.TryGetValue(aKey, Result) then
    begin
      Result := FGetValue(aKey);
      FMap.Add(aKey, Result);
      if FMap.Count > FSizeLimit then
        FMap.RemoveFirst;
    end;
end;

end.

