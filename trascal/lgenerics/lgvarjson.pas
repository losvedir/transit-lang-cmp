{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Minimalistic JSON utility based on custom variant type.                 *
*                                                                           *
*   Copyright(c) 2021-2022 A.Koverdyaev(avk)                                *
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
unit lgVarJson;

{$MODE OBJFPC}{$H+}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH TYPEHELPERS}

interface

uses
  Classes, SysUtils, Variants, lgUtils, lgJson, lgStrConst;

type

  TVPair      = specialize TGMapEntry<string, Variant>;
  TVPairArray = array of TVPair;

  { TVarJson }
  TVarJson = packed record
  private
    VType:  TVarType;
    Dummy1: Word;
    FRoot:  Boolean;
    Dummy2: array[0..2] of Byte;
    FRefCount: PInteger;
    FNode: TJsonNode;
  public
    function IsVarJson: Boolean; inline;
  private
  type
    TVarKind = (vkNull, vkBool, vkNumber, vkString, vkArray, vkNode, vkUnknown);
    procedure _AddRef; inline;
    procedure _Release; inline;
    class procedure CopyNode(const aSrc: TVarJson; var aDst: TVarJson); static;
    class function  VarKind(const aValue: Variant): TVarKind; static;
    class function  CanCast(const aValue: Variant): Boolean; static;
    class procedure NodeToVar(aNode: TJsonNode;  var aDst: TVarData); static;
    class procedure VarToNode(const aValue: Variant; aNode: TJsonNode); static;
    procedure Init(aNode: TJsonNode; aRoot: Boolean = False);
    procedure GetProperty(const aName: string; var aDst: TVarData);
    procedure SetProperty(const aName: string; const aValue: Variant);
    function  GetValueProp(const aName: string): Variant;
    procedure SetValueProp(const aName: string; const aValue: Variant);
    function  GetItemProp(aIndex: SizeInt): Variant;
    procedure SetItemProp(aIndex: SizeInt; const aValue: Variant);
    function  GetKind: TJsValueKind;
    function  GetCount: SizeInt;
    function  GetIsScalar: Boolean;
    function  GetIsStruct: Boolean;
    function  GetIsInteger: Boolean;
    function  GetHasUniqueNames: Boolean;
    function  GetPair(aIndex: SizeInt): TVPair;
  public
  { converts an instance to null }
    procedure SetNull;
  { converts an instance to a Boolean }
    procedure SetBoolean(aValue: Boolean);
  { converts an instance to a number }
    procedure SetNumber(aValue: Double);
  { converts an instance to a string }
    procedure SetString(const aValue: string);
  { adds aValue to the instance as to an array; if it is not an array,
    it is cleared and becomes an array; raises an exception if aValue cannot be cast;
    returns Self as Variant }
    function  AddItem(const aValue: Variant): Variant;
    function  AddJsonItem(const aJson: string): Boolean;
  { adds an object item aValue to the instance as to an array; if it is not an array,
    it is cleared and becomes an array; raises an exception if aValue cannot be cast;
    returns Self as Variant; cannot be called through DispInvoke }
    function  AddObjItem(const aValue: TVPairArray): Variant;
  { adds an empty item to the instance as to an array; returns new item as Variant }
    function  AddEmptyItem: Variant;
  { adds aValue associated with aName to the instance as to an object;
    if it is not an object, it is cleared and becomes an object;
    raises an exception if aValue cannot be cast; returns Self as Variant }
    function  AddValue(const aName: string; const aValue: Variant): Variant;
    function  AddJsonValue(const aName, aJson: string): Boolean;
  { adds an object item aValue  associated with aName to the instance as to an object;
    if it is not an object, it is cleared and becomes an object; raises an exception
    if aValue cannot be cast; returns Self as Variant; cannot be called through DispInvoke }
    function  AddObjValue(const aName: string; const aValue: TVPairArray): Variant;
  { adds an empty item  associated with aName to the instance as to an array;
    returns new item as Variant }
    function  AddEmptyValue(const aName: string): Variant;
  { returns Null if the instance does not contain an element with index aIndex,
    otherwise it returns this element as Variant }
    function  GetItem(aIndex: SizeInt): Variant;
  { assigns the specified aValue to the element with index aIndex;
    raises an exception if aValue cannot be cast to a valid JSON type or
    the element with index aIndex does not exist; returns Self as Variant }
    function  SetItem(aIndex: SizeInt; const aValue: Variant): Variant;
  { returns Null if the instance does not contain an element with specified aName,
    otherwise it returns this element as Variant }
    function  GetValue(const aName: string): Variant;
  { assigns the aValue to the element associated with specified name;
    raises an exception if aValue cannot be cast to a valid JSON type;
    returns Self as Variant }
    function  SetValue(const aName: string; const aValue: Variant): Variant;
  { tries to find an element using the path specified as a JSON Pointer;
    raises an exception if aPtr is not a well-formed JSON Pointer }
    function  FindPath(const aPtr: string): Variant;
    function  FindPath(const aPath: TStringArray): Variant;
    procedure CopyFrom(const aValue: Variant);
  { note: the names of properties and functions that do not have parameters can be used
    through DispInvoke only for their intended purpose }
    function  Clone: Variant;
    function  AsJson: string;
    function  FormatJson(aOptions: TJsFormatOptions = []; aOffs: Integer = 0;
                         aIndent: Integer = DEF_INDENT): string;
    function  ToString: string;
    function  ToValue: Variant;
    property  Kind: TJsValueKind read GetKind;
    property  Count: SizeInt read GetCount;
    property  IsScalar: Boolean read GetIsScalar;
    property  IsStruct: Boolean read GetIsStruct;
    property  IsInteger: Boolean read GetIsInteger;
    property  DupeNamesFree: Boolean read GetHasUniqueNames;
    property  Values[const aName: string]: Variant read GetValueProp write SetValueProp; default;
    property  Items[aIndex: SizeInt]: Variant read GetItemProp write SetItemProp;
    property  Pairs[aIndex: SizeInt]: TVPair read GetPair;
  end;


  TVarHelper = type helper for Variant
    function IsJson: Boolean;
    function IsJsValueKind: Boolean;
    function AsJsValueKind: TJsValueKind;
  end;

  { TJsonVariant }
  TJsonVariant = class(TInvokeableVariantType)
    function  IsClear(const V: TVarData): Boolean; override;
    procedure Cast(var aDst: TVarData; const aSrc: TVarData); override;
    procedure CastTo(var aDst: TVarData; const aSrc: TVarData; const aVarType: TVarType); override;
    procedure Copy(var aDst: TVarData; const aSrc: TVarData; const aIndirect: Boolean); override;
    procedure Clear(var aData: TVarData); override;
    function  CompareOp(const L, R: TVarData; const aOp: TVarOp): Boolean; override;
    function  DoFunction(var aDst: TVarData; const V: TVarData; const aName: string;
                         const Args: TVarDataArray): Boolean; override;
    function  DoProcedure(const V: TVarData; const aName: string;
                          const Args: TVarDataArray): Boolean; override;
    function  GetProperty(var aDst: TVarData; const aData: TVarData; const aName: string): Boolean; override;
    function  SetProperty(var aData: TVarData; const aName: string; const aValue: TVarData): Boolean; override;
  end;

  function VarJsonCreate(const s: string): Variant;
  function VarJsonCreate(const aStream: TStream): Variant;
  function VarJsonCreate(const aStream: TStream; aCount: SizeInt): Variant;
  function VarJsonFromFile(const aFileName: string): Variant;
  function VarJsonCreate(const a: TJVarArray): Variant;
  function VarJsonCreate(const a: TJPairArray): Variant;
  function VarJsonCreate(const aValue: Variant): Variant;
  function VarJsonCreate(const a: TVPairArray): Variant;
  function VarJsonCreate: Variant;


  function VarJson: TVarType; inline;
  function VarIsJson(const V: Variant): Boolean; inline;

implementation
{$B-}{$COPERATORS ON}

var
  JsonVariant: TInvokeableVariantType;

function VarJsonCreate(const s: string): Variant;
var
  Node: TJsonNode;
begin
  Result := Null;
  if TJsonNode.TryParse(s, Node) then
    TVarJson(Result).Init(Node, True);
end;

function VarJsonCreate(const aStream: TStream): Variant;
var
  Node: TJsonNode;
begin
  Result := Null;
  if TJsonNode.TryParse(aStream, Node) then
    TVarJson(Result).Init(Node, True);
end;

function VarJsonCreate(const aStream: TStream; aCount: SizeInt): Variant;
var
  Node: TJsonNode;
begin
  Result := Null;
  if TJsonNode.TryParse(aStream, aCount, Node) then
    TVarJson(Result).Init(Node, True);
end;

function VarJsonFromFile(const aFileName: string): Variant;
var
  Node: TJsonNode;
begin
  Result := Null;
  if TJsonNode.TryParseFile(aFileName, Node) then
    TVarJson(Result).Init(Node, True);
end;

function VarJsonCreate(const a: TJVarArray): Variant;
begin
  Result := Null;
  TVarJson(Result).Init(TJsonNode.Create(a), True);
end;

function VarJsonCreate(const a: TJPairArray): Variant;
begin
  Result := Null;
  TVarJson(Result).Init(TJsonNode.Create(a), True);
end;

function VarJsonCreate(const aValue: Variant): Variant;
var
  Node: TJsonNode;
begin
  Result := Null;
  Node := TJsonNode.Create;
  TVarJson.VarToNode(aValue, Node);
  TVarJson(Result).Init(Node, True);
end;

function VarJsonCreate(const a: TVPairArray): Variant;
var
  p: TVPair;
begin
  Result := Null;
  TVarJson(Result).Init(TJsonNode.Create, True);
  for p in a do
    TVarJson(Result).SetProperty(p.Key, p.Value);
end;

function VarJsonCreate: Variant;
begin
  Result := Null;
  TVarJson(Result).Init(nil, True);
end;

function VarJson: TVarType;
begin
  Result := JsonVariant.VarType;
end;

function VarIsJson(const V: Variant): Boolean;
begin
  Result := TVarData(V).VType = JsonVariant.VarType;
end;

{ TVarJson }

function TVarJson.IsVarJson: Boolean;
begin
  Result := (@Self <> nil) and (VType = VarJson);
end;

procedure TVarJson._AddRef;
begin
  if FRoot then InterlockedIncrement(FRefCount^);
end;

procedure TVarJson._Release;
begin
  if FRoot and (InterlockedDecrement(FRefCount^) = 0) then
    begin
      FNode.Free;
      System.Dispose(FRefCount);
    end;
end;

class procedure TVarJson.CopyNode(const aSrc: TVarJson; var aDst: TVarJson);
begin
  aSrc._AddRef;
  aDst := aSrc;
end;

class function TVarJson.VarKind(const aValue: Variant): TVarKind;
begin
  if VarIsArray(aValue) then
    exit(vkArray);
  if TVarData(aValue).VType = VarJson then
    exit(vkNode);
  case TVarData(aValue).VType of
    varEmpty,
    varNull:    Result := vkNull;
    varBoolean: Result := vkBool;
    varShortInt,
    varSmallInt,
    varInteger,
    varSingle,
    varDouble,
    varByte,
    varWord,
    varLongWord,
    varInt64,
    varQWord:   Result := vkNumber;
    varOleStr,
    varString,
    varUString: Result := vkString;
  else
    Result := vkUnknown;
  end;
end;

class function TVarJson.CanCast(const aValue: Variant): Boolean;
var
  I: Integer;
  vk: TVarKind;
begin
  vk := VarKind(aValue);
  if vk = vkUnknown then
    exit(False);
  if vk = vkArray then
    begin
      if VarArrayDimCount(aValue) <> 1 then
        exit(False);
      for I := VarArrayLowBound(aValue, 1) to VarArrayHighBound(aValue, 1) do
        if not CanCast(aValue[I]) then
          exit(False);
    end;
  Result := True;
end;

class procedure TVarJson.NodeToVar(aNode: TJsonNode; var aDst: TVarData);
var
  I64: Int64;
  d: Double;
begin
  if aNode = nil then
    begin
      Variant(aDst) := Null;
      exit;
    end;
  case aNode.Kind of
    jvkUnknown,
    jvkNull:    Variant(aDst) := Null;
    jvkFalse:   Variant(aDst) := False;
    jvkTrue:    Variant(aDst) := True;
    jvkNumber:
      begin
        d := aNode.AsNumber;
        if IsExactInt(d, I64) then
          Variant(aDst) := I64
        else
          Variant(aDst) := d;
      end;
    jvkString: Variant(aDst) := aNode.AsString;
    jvkArray,
    jvkObject: Variant(aDst) := aNode.AsJson;
  end;
end;

class procedure TVarJson.VarToNode(const aValue: Variant; aNode: TJsonNode);
var
  I: Integer;
  Node: TJsonNode;
begin
  case VarKind(aValue) of
    vkNull:   aNode.AsNull;
    vkBool:   aNode.AsBoolean := aValue;
    vkNumber: aNode.AsNumber := aValue;
    vkString: aNode.AsString := string(aValue);
    vkArray:
      begin
        for I := VarArrayLowBound(aValue, 1) to VarArrayHighBound(aValue, 1) do
          if VarIsArray(aValue[I]) then
            begin
              Node := aNode.AddNode(jvkUnknown);
              VarToNode(aValue[I], Node);
            end
          else
            case VarKind(TVarData(aValue[I]).VType) of
              vkNull:   aNode.AddNull;
              vkBool:   aNode.Add(Boolean(aValue[I]));
              vkNumber: aNode.Add(Double(aValue[I]));
              vkString: aNode.Add(string(aValue[I]));
            else
            end;
      end;
    vkNode: aNode.CopyFrom(TVarJson(aValue).FNode);
  else
  end;
end;

procedure TVarJson.Init(aNode: TJsonNode; aRoot: Boolean);
begin
  Assert(SizeOf(Dummy1) = SizeOf(Dummy1)); //make the compiler happy
  Assert(SizeOf(Dummy2) = SizeOf(Dummy2));
  VType := VarJson;
  FNode := aNode;
  FRoot := aRoot;
  if aRoot then
    begin
      System.New(FRefCount);
      FRefCount^ := 1;
    end;
end;

procedure TVarJson.GetProperty(const aName: string; var aDst: TVarData);
var
  Node: TJsonNode = nil;
begin
  Variant(aDst) := Null;
  if (FNode <> nil) and FNode.Find(aName, Node) then
    TVarJson(aDst).Init(Node);
end;

procedure TVarJson.SetProperty(const aName: string; const aValue: Variant);
var
  Node: TJsonNode;
begin
  if not CanCast(aValue) then
    VarCastError;
  if FNode = nil then
    FNode := TJsonNode.Create;
  FNode.FindOrAdd(aName, Node);
  VarToNode(aValue, Node);
end;

function TVarJson.GetValueProp(const aName: string): Variant;
var
  Node: TJsonNode;
begin
  Result := Null;
  if not IsVarJson then exit;
  if (FNode <> nil) and FNode.Find(aName, Node) then
    TVarJson(Result).Init(Node);
end;

procedure TVarJson.SetValueProp(const aName: string; const aValue: Variant);
begin
  if not IsVarJson then exit;
  SetProperty(aName, aValue);
end;

function TVarJson.GetItemProp(aIndex: SizeInt): Variant;
var
  Node: TJsonNode;
begin
  Result := Null;
  if not IsVarJson then exit;
  if (FNode <> nil) and FNode.Find(aIndex, Node) then
    TVarJson(Result).Init(Node);
end;

procedure TVarJson.SetItemProp(aIndex: SizeInt; const aValue: Variant);
var
  Node: TJsonNode;
begin
  if not IsVarJson then exit;
  if not CanCast(aValue) then
    VarCastError;
  if FNode = nil then
    begin
      if aIndex <> 0 then
        raise EJsException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
      FNode := TJsonNode.Create(jvkArray);
    end
  else
    FNode.AsArray;
  if SizeUInt(aIndex) > SizeUInt(FNode.Count) then
    raise EJsException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
  if aIndex = FNode.Count then
    FNode.InsertNode(aIndex, Node, jvkUnknown)
  else
    FNode.Find(aIndex, Node);
  VarToNode(aValue, Node);
end;

function TVarJson.GetKind: TJsValueKind;
begin
  if not IsVarJson or (FNode = nil) then
    exit(jvkUnknown);
  Result := FNode.Kind;
end;

function TVarJson.GetCount: SizeInt;
begin
  if not IsVarJson or (FNode = nil) then
    exit(0);
  Result := FNode.Count;
end;

function TVarJson.GetIsScalar: Boolean;
begin
  if not IsVarJson or (FNode = nil) then
    exit(True);
  Result := FNode.IsScalar;
end;

function TVarJson.GetIsStruct: Boolean;
begin
  if not IsVarJson or (FNode = nil) then
    exit(False);
  Result := FNode.IsStruct;
end;

function TVarJson.GetIsInteger: Boolean;
begin
  if not IsVarJson or (FNode = nil) then
    exit(False);
  Result := FNode.IsInteger;
end;

function TVarJson.GetHasUniqueNames: Boolean;
begin
  if not IsVarJson or (FNode = nil) then
    exit(True);
  Result := TJsonNode.DupeNamesFree(FNode);
end;

function TVarJson.GetPair(aIndex: SizeInt): TVPair;
begin
  Result := TVPair.Create('', Null);
  if not IsVarJson then exit;
  if (FNode = nil) or (Kind <> jvkObject) then
    exit;
  if SizeUInt(aIndex) >= SizeUInt(FNode.Count) then
    exit;
  with FNode.Pairs[aIndex] do
    begin
      Result.Key := Key;
      TVarJson(Result.Value).Init(Value);
    end;
end;

procedure TVarJson.SetNull;
begin
  if not IsVarJson then exit;
  if FNode = nil then
    FNode := TJsonNode.CreateNull
  else
    FNode.AsNull;
end;

procedure TVarJson.SetBoolean(aValue: Boolean);
begin
  if not IsVarJson then exit;
  if FNode = nil then
    FNode := TJsonNode.Create(aValue)
  else
    FNode.AsBoolean := aValue;
end;

procedure TVarJson.SetNumber(aValue: Double);
begin
  if not IsVarJson then exit;
  if FNode = nil then
    FNode := TJsonNode.Create(aValue)
  else
    FNode.AsNumber := aValue;
end;

procedure TVarJson.SetString(const aValue: string);
begin
  if not IsVarJson then exit;
  if FNode = nil then
    FNode := TJsonNode.Create(aValue)
  else
    FNode.AsString := aValue;
end;

function TVarJson.AddItem(const aValue: Variant): Variant;
var
  Node: TJsonNode;
begin
  Result := Null;
  if not IsVarJson then exit;
  if not CanCast(aValue) then
    VarCastError;
  if FNode = nil then
    FNode := TJsonNode.Create;
  Node := FNode.AddNode(jvkUnknown);
  VarToNode(aValue, Node);
  CopyNode(Self, TVarJson(Result));
end;

function TVarJson.AddJsonItem(const aJson: string): Boolean;
var
  Node: TJsonNode;
begin
  if not IsVarJson then exit(False);
  if FNode = nil then
    FNode := TJsonNode.Create;
  Result := FNode.AddJson(aJson, Node);
end;

function TVarJson.AddObjItem(const aValue: TVPairArray): Variant;
var
  Node, NestNode: TJsonNode;
  p: TVPair;
begin
  Result := Null;
  if not IsVarJson then exit;
  p := TVPair.Create('', Null);
  for p in aValue do
    if not CanCast(p.Value) then
      VarCastError;
  if FNode = nil then
    FNode := TJsonNode.Create;
  Node := FNode.AddNode(jvkUnknown);
  for p in aValue do
    begin
      NestNode := Node.AddNode(p.Key, jvkUnknown);
      VarToNode(p.Value, NestNode);
    end;
  CopyNode(Self, TVarJson(Result));
end;

function TVarJson.AddEmptyItem: Variant;
begin
  Result := Null;
  if not IsVarJson then exit;
  if FNode = nil then
    FNode := TJsonNode.Create;
  TVarJson(Result).Init(FNode.AddNode(jvkUnknown));
end;

function TVarJson.AddValue(const aName: string; const aValue: Variant): Variant;
var
  Node: TJsonNode;
begin
  Result := Null;
  if not IsVarJson then exit;
  if not CanCast(aValue) then
    VarCastError;
  if FNode = nil then
    FNode := TJsonNode.Create;
  Node := FNode.AddNode(aName, jvkUnknown);
  VarToNode(aValue, Node);
  CopyNode(Self, TVarJson(Result));
end;

function TVarJson.AddJsonValue(const aName, aJson: string): Boolean;
var
  Node: TJsonNode;
begin
  if not IsVarJson then exit(False);
  if FNode = nil then
    FNode := TJsonNode.Create;
  Result := FNode.AddJson(aName, aJson, Node);
end;

function TVarJson.AddObjValue(const aName: string; const aValue: TVPairArray): Variant;
var
  Node, NestNode: TJsonNode;
  p: TVPair;
begin
  Result := Null;
  if not IsVarJson then exit;
  p := TVPair.Create('', Null);
  for p in aValue do
    if not CanCast(p.Value) then
      VarCastError;
  if FNode = nil then
    FNode := TJsonNode.Create;
  Node := FNode.AddNode(aName, jvkUnknown);
  for p in aValue do
    begin
      NestNode := Node.AddNode(p.Key, jvkUnknown);
      VarToNode(p.Value, NestNode);
    end;
  CopyNode(Self, TVarJson(Result));
end;

function TVarJson.AddEmptyValue(const aName: string): Variant;
begin
  Result := Null;
  if not IsVarJson then exit;
  if FNode = nil then
    FNode := TJsonNode.Create;
  TVarJson(Result).Init(FNode.AddNode(aName, jvkUnknown));
end;

function TVarJson.GetItem(aIndex: SizeInt): Variant;
var
  Node: TJsonNode;
begin
  Result := Null;
  if not IsVarJson then exit;
  if (FNode <> nil) and FNode.Find(aIndex, Node) then
    TVarJson(Result).Init(Node);
end;

function TVarJson.SetItem(aIndex: SizeInt; const aValue: Variant): Variant;
begin
  Result := Null;
  if not IsVarJson then exit;
  SetItemProp(aIndex, aValue);
  CopyNode(Self, TVarJson(Result));
end;

function TVarJson.GetValue(const aName: string): Variant;
var
  Node: TJsonNode = nil;
begin
  Result := Null;
  if not IsVarJson then exit;
  if (FNode <> nil) and FNode.Find(aName, Node) then
    TVarJson(Result).Init(Node);
end;

function TVarJson.SetValue(const aName: string; const aValue: Variant): Variant;
begin
  Result := Null;
  if not IsVarJson then exit;
  SetValueProp(aName, aValue);
  CopyNode(Self, TVarJson(Result));
end;

function TVarJson.FindPath(const aPtr: string): Variant;
var
  Ptr: TJsonPtr;
  Node: TJsonNode;
begin
  Result := Null;
  if not IsVarJson then exit;
  if FNode = nil then
    exit;
  if aPtr = '' then
    begin
      CopyNode(Self, TVarJson(Result));
      exit;
    end;
  Ptr := TJsonPtr.From(aPtr);
  if FNode.FindPath(Ptr, Node) then
    TVarJson(Result).Init(Node);
end;

function TVarJson.FindPath(const aPath: TStringArray): Variant;
var
  Node: TJsonNode;
begin
  Result := Null;
  if not IsVarJson then exit;
  if FNode = nil then
    exit;
  if aPath = nil then
    begin
      CopyNode(Self, TVarJson(Result));
      exit;
    end;
  if FNode.FindPath(aPath, Node) then
    TVarJson(Result).Init(Node);
end;

procedure TVarJson.CopyFrom(const aValue: Variant);
begin
  if not IsVarJson then exit;
  if aValue.IsJson then
    if TVarJson(aValue).FNode <> nil then
      begin
        if FNode = nil then
          FNode := TJsonNode.Create;
        FNode.CopyFrom(TVarJson(aValue).FNode);
      end
    else
      if FNode <> nil then
        FNode.Clear;
end;

function TVarJson.Clone: Variant;
begin
  Result := Null;
  if not IsVarJson then exit;
  if FNode <> nil then
    TVarJson(Result).Init(FNode.Clone, True)
  else
    TVarJson(Result).Init(nil, True);
end;

function TVarJson.AsJson: string;
begin
  if not IsVarJson or (FNode = nil) then
    exit('');
  Result := FNode.AsJson;
end;

function TVarJson.FormatJson(aOptions: TJsFormatOptions; aOffs, aIndent: Integer): string;
begin
  if not IsVarJson or (FNode = nil) then
    exit('');
  Result := FNode.FormatJson(aOptions, aOffs, aIndent);
end;

function TVarJson.ToString: string;
begin
  if not IsVarJson or (FNode = nil) then
    exit('');
  Result := FNode.ToString;
end;

function TVarJson.ToValue: Variant;
begin
  Result := Null;
  if not IsVarJson then exit;
  if FNode <> nil then
    NodeToVar(FNode, TVarData(Result));
end;

{ TVarHelper }

function TVarHelper.IsJson: Boolean;
begin
  Result := TVarJson(Self).IsVarJson;
end;

function TVarHelper.IsJsValueKind: Boolean;
begin
  with TVarData(Self) do
    Result := (VType = varInteger) and (VInteger >= Ord(Low(TJsValueKind))) and
              (VInteger <= Ord(High(TJsValueKind)));
end;

function TVarHelper.AsJsValueKind: TJsValueKind;
begin
  if not IsJsValueKind then
    VarCastError;
  Result := TJsValueKind(TVarData(Self).VInteger);
end;

{ TJsonVariant }

function TJsonVariant.IsClear(const V: TVarData): Boolean;
begin
  Result := TVarJson(V).VType = varEmpty;
end;

procedure TJsonVariant.Cast(var aDst: TVarData; const aSrc: TVarData);
begin
  if TVarJson(aDst).FNode = nil then
    TVarJson(aDst).Init(TJsonNode.Create, True);
  TVarJson.VarToNode(Variant(aSrc), TVarJson(aDst).FNode);
end;

procedure TJsonVariant.CastTo(var aDst: TVarData; const aSrc: TVarData; const aVarType: TVarType);
var
  I64: Int64 = 0;
begin
  if TVarJson(aSrc).FNode = nil then
    RaiseCastError;
  with TVarJson(aSrc) do
    case aVarType of
      varBoolean:
        if FNode.IsBoolean then
          Variant(aDst) := FNode.AsBoolean
        else
          RaiseCastError;
      varInteger,
      varLongWord,
      varInt64,
      varQWord:
        if FNode.IsInteger then
          begin
            IsExactInt(FNode.AsNumber, I64);
            if aVarType = varInteger then
              Variant(aDst) := Integer(I64)
            else
              if aVarType = varLongWord then
                Variant(aDst) := LongWord(I64)
              else
                if aVarType = varInt64 then
                  Variant(aDst) := I64
                else
                  Variant(aDst) := QWord(I64);
          end
        else
          RaiseCastError;
      varDouble:
        if FNode.IsNumber then
          Variant(aDst) := FNode.AsNumber
        else
          RaiseCastError;
      varString:
        if FNode.IsString then
          Variant(aDst) := FNode.AsString
        else
          Variant(aDst) := FNode.ToString;
    else
      RaiseCastError;
    end;
end;

procedure TJsonVariant.Copy(var aDst: TVarData; const aSrc: TVarData; const aIndirect: Boolean);
begin
  Assert(aIndirect = aIndirect); //make the compiler happy
  VarClear(Variant(aDst));
  TVarJson.CopyNode(TVarJson(aSrc), TVarJson(aDst));
end;

procedure TJsonVariant.Clear(var aData: TVarData);
begin
  TVarJson(aData)._Release;
  TVarJson(aData).VType := varEmpty;
end;

function TJsonVariant.CompareOp(const L, R: TVarData; const aOp: TVarOp): Boolean;
begin
  if aOp <> opcmpeq then
    Result := inherited CompareOp(L, R, aOp)
  else
    Result := TVarJson(L).FNode.EqualTo(TVarJson(R).FNode);
end;

function TJsonVariant.DoFunction(var aDst: TVarData; const V: TVarData; const aName: string;
  const Args: TVarDataArray): Boolean;
begin
  //VarClear(Variant(aDst));
  case LowerCase(aName) of
    'addemptyvalue':
      begin
        if System.Length(Args) <> 1 then
          RaiseDispError;
        Variant(aDst) := TVarJson(V).AddEmptyValue(Variant(Args[0]));
        exit(True);
      end;
    'additem':
      begin
        if System.Length(Args) <> 1 then
          RaiseDispError;
        Variant(aDst) := TVarJson(V).AddItem(Variant(Args[0]));
        exit(True);
      end;
    'addjsonitem':
      begin
        if System.Length(Args) <> 1 then
          RaiseDispError;
        Variant(aDst) := TVarJson(V).AddJsonItem(Variant(Args[0]));
        exit(True);
      end;
    'addjsonvalue':
      begin
        if System.Length(Args) <> 2 then
          RaiseDispError;
        Variant(aDst) := TVarJson(V).AddJsonValue(Variant(Args[0]), Variant(Args[1]));
        exit(True);
      end;
    'addvalue':
      begin
        if System.Length(Args) <> 2 then
          RaiseDispError;
        Variant(aDst) := TVarJson(V).AddValue(Variant(Args[0]), Variant(Args[1]));
        exit(True);
      end;
    'findpath':
      begin
        if System.Length(Args) <> 1 then
          RaiseDispError;
        Variant(aDst) := TVarJson(V).FindPath(Variant(Args[0]));
        exit(True);
      end;
    'getitem':
      begin
        if System.Length(Args) <> 1 then
          RaiseDispError;
        Variant(aDst) := TVarJson(V).GetItem(Variant(Args[0]));
        exit(True);
      end;
    'getvalue':
      begin
        if System.Length(Args) <> 1 then
          RaiseDispError;
        Variant(aDst) := TVarJson(V).GetValue(Variant(Args[0]));
        exit(True);
      end;
    'setitem':
      begin
        if System.Length(Args) <> 2 then
          RaiseDispError;
        Variant(aDst) := TVarJson(V).SetItem(Variant(Args[0]), Variant(Args[1]));
        exit(True);
      end;
    'setvalue':
      begin
        if System.Length(Args) <> 2 then
          RaiseDispError;
        Variant(aDst) := TVarJson(V).SetValue(Variant(Args[0]), Variant(Args[1]));
        exit(True);
      end;
  end;
  Result := False;
end;

function TJsonVariant.DoProcedure(const V: TVarData; const aName: string; const Args: TVarDataArray): Boolean;
begin
  case LowerCase(aName) of
    'copyfrom':
      begin
        TVarJson(V).CopyFrom(Variant(Args[0]));
        exit(True);
      end;
    'setnull':
      begin
        TVarJson(V).SetNull;
        exit(True);
      end;
    'setboolean':
      begin
        if System.Length(Args) <> 1  then
          RaiseDispError;
        TVarJson(V).SetBoolean(Variant(Args[0]));
        exit(True);
      end;
    'setnumber':
      begin
        if System.Length(Args) <> 1 then
          RaiseDispError;
        TVarJson(V).SetNumber(Variant(Args[0]));
        exit(True);
      end;
    'setstring':
      begin
        if System.Length(Args) <> 1 then
          RaiseDispError;
        TVarJson(V).SetString(Variant(Args[0]));
        exit(True);
      end;
  end;
  Result := False;
end;

function TJsonVariant.GetProperty(var aDst: TVarData; const aData: TVarData;
  const aName: string): Boolean;
begin
  Result := True;
  case LowerCase(aName) of
    'addemptyitem':   Variant(aDst) := TVarJson(aData).AddEmptyItem;
    'asjson':         Variant(aDst) := TVarJson(aData).AsJson;
    'clone':          Variant(aDst) := TVarJson(aData).Clone;
    'count':          Variant(aDst) := TVarJson(aData).Count;
    'formatjson':     Variant(aDst) := TVarJson(aData).AsJson;
    'dupenamesfree':  Variant(aDst) := TVarJson(aData).DupeNamesFree;
    'isinteger':      Variant(aDst) := TVarJson(aData).IsInteger;
    'isscalar':       Variant(aDst) := TVarJson(aData).IsScalar;
    'isstruct':       Variant(aDst) := TVarJson(aData).IsStruct;
    'kind':           Variant(aDst) := Integer(TVarJson(aData).Kind);
    'tostring':       Variant(aDst) := TVarJson(aData).ToString;
    'tovalue':        Variant(aDst) := TVarJson(aData).ToValue;
  else
    TVarJson(aData).GetProperty(aName, aDst);
  end;
end;

function TJsonVariant.SetProperty(var aData: TVarData; const aName: string;
  const aValue: TVarData): Boolean;
begin
  Result := True;
  TVarJson(aData).SetProperty(aName, Variant(aValue));
end;

initialization
  JsonVariant := TJsonVariant.Create;
finalization
  JsonVariant.Free;
end.

