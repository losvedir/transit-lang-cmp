{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Some common BST utilities.                                              *
*   Copyright(c) 2019-2022 A.Koverdyaev(avk)                                *
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
unit lgBstUtils;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}

interface

uses
  SysUtils,
  lgUtils,
  {%H-}lgHelpers;

type

  { TGBaseBstUtil - binary search tree utility, it assumes TNode is a record type and
    it allocates memory with System.GetMem;
      TNode must provide:
        field/property/function Key: TKey;
        field/property/function Left: ^TNode;
        field/property/function Right: ^TNode; }
  generic TGBaseBstUtil<TNode> = class
  public
  type
    PNode      = ^TNode;
    TOnVisit   = procedure(aNode: PNode; var aGoOn: Boolean) of object;
    TNestVisit = procedure(aNode: PNode; var aGoOn: Boolean) is nested;

    class function  GetTreeSize(aNode: PNode): SizeInt; static;
    class function  GetHeight(aNode: PNode): SizeInt; static;
    class function  GetLowest(aRoot: PNode): PNode; static;
    class function  GetHighest(aRoot: PNode): PNode; static;
    class procedure ClearTree(aNode: PNode); static;
    class procedure FreeNode(aNode: PNode); static; inline;
    class function  PreOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt; static;
    class function  PreOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt; static;
    class function  InOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt; static;
    class function  InOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt; static;
    class function  PostOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt; static;
    class function  PostOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt; static;
  end;

  { TGBstUtil - functor TCmpRel (comparison relation) must provide:
                  class function Less([const[ref]] L, R: TKey): Boolean; }
  generic TGBstUtil<TKey, TNode, TCmpRel> = class(specialize TGBaseBstUtil<TNode>)
  public
    class function  FindKey(aRoot: PNode; const aKey: TKey): PNode; static;
    class function  GetLess(aRoot: PNode; const aKey: TKey): PNode; static;
    class function  GetLessOrEqual(aRoot: PNode; const aKey: TKey): PNode;static;
    class function  GetGreater(aRoot: PNode; const aKey: TKey): PNode; static;
    class function  GetGreaterOrEqual(aRoot: PNode; const aKey: TKey): PNode; static;
  end;

  { TGComparableBstUtil assumes TKey has defined comparison operator < }
  generic TGComparableBstUtil<TKey, TNode> = class(specialize TGBaseBstUtil<TNode>)
  public
    class function  FindKey(aRoot: PNode; const aKey: TKey): PNode; static;
    class function  GetLess(aRoot: PNode; const aKey: TKey): PNode; static;
    class function  GetLessOrEqual(aRoot: PNode; const aKey: TKey): PNode;static;
    class function  GetGreater(aRoot: PNode; const aKey: TKey): PNode; static;
    class function  GetGreaterOrEqual(aRoot: PNode; const aKey: TKey): PNode; static;
  end;

  { TGIndexedBstUtil assumes TNode has also a field/property/function Size: SizeInt,
    which is the size of its subtree }
  generic TGIndexedBstUtil<TKey, TNode, TCmpRel> = class(specialize TGBstUtil<TKey, TNode, TCmpRel>)
  public
    class function GetNodeSize(aNode: PNode): SizeInt; static; inline;
    class function GetByIndex(aRoot: PNode; aIndex: SizeInt): PNode; static;
    class function GetKeyIndex(aRoot: PNode; const aKey: TKey): SizeInt;
  end;

  { TGCmpIndexedBstUtil assumes TNode has also a field/property/function Size: SizeInt,
    which is the size of its subtree }
  generic TGCmpIndexedBstUtil<TKey, TNode> = class(specialize TGComparableBstUtil<TKey, TNode>)
  public
    class function GetNodeSize(aNode: PNode): SizeInt; static; inline;
    class function GetByIndex(aRoot: PNode; aIndex: SizeInt): PNode; static;
    class function GetKeyIndex(aRoot: PNode; const aKey: TKey): SizeInt;
  end;

implementation
{$B-}{$COPERATORS ON}

{ TGBaseBstUtil }

class function TGBaseBstUtil.GetTreeSize(aNode: PNode): SizeInt;
var
  Size: SizeInt = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Inc(Size);
        Visit(aNode^.Left);
        Visit(aNode^.Right);
      end;
  end;
begin
  Visit(aNode);
  Result := Size;
end;

class function TGBaseBstUtil.GetHeight(aNode: PNode): SizeInt;
var
  RHeight: SizeInt = 0;
begin
  Result := 0;
  if aNode = nil then exit;
  if aNode^.Left <> nil then
    Result := Succ(GetHeight(aNode^.Left));
  if aNode^.Right <> nil then
    RHeight := Succ(GetHeight(aNode^.Right));
  if RHeight > Result then
    Result := RHeight;
end;

class function TGBaseBstUtil.GetLowest(aRoot: PNode): PNode;
begin
  Result := aRoot;
  if Result <> nil then
    while Result^.Left <> nil do
      Result := Result^.Left;
end;

class function TGBaseBstUtil.GetHighest(aRoot: PNode): PNode;
begin
  Result := aRoot;
  if Result <> nil then
    while Result^.Right <> nil do
      Result := Result^.Right;
end;

class procedure TGBaseBstUtil.ClearTree(aNode: PNode);
begin
  if aNode <> nil then
    begin
      ClearTree(aNode^.Left);
      ClearTree(aNode^.Right);
      //if IsManagedType(TNode) then
        aNode^ := Default(TNode);
      System.FreeMem(aNode);
    end;
end;

class procedure TGBaseBstUtil.FreeNode(aNode: PNode);
begin
  //if IsManagedType(TNode) then
    aNode^ := Default(TNode);
  System.FreeMem(aNode);
end;

class function TGBaseBstUtil.PreOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        if aOnVisit <> nil then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
        Visit(aNode^.Left);
        Visit(aNode^.Right);
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

class function TGBaseBstUtil.PreOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        if aOnVisit <> nil then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
        Visit(aNode^.Left);
        Visit(aNode^.Right);
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

class function TGBaseBstUtil.InOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        Visit(aNode^.Left);
        if (aOnVisit <> nil) and Goon then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
        Visit(aNode^.Right);
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

class function TGBaseBstUtil.InOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        Visit(aNode^.Left);
        if (aOnVisit <> nil) and Goon then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
        Visit(aNode^.Right);
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

class function TGBaseBstUtil.PostOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        Visit(aNode^.Left);
        Visit(aNode^.Right);
        if (aOnVisit <> nil) and Goon then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

class function TGBaseBstUtil.PostOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        Visit(aNode^.Left);
        Visit(aNode^.Right);
        if (aOnVisit <> nil) and Goon then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

{ TGBstUtil }

class function TGBstUtil.FindKey(aRoot: PNode; const aKey: TKey): PNode;
begin
  while aRoot <> nil do
    if TCmpRel.Less(aKey, aRoot^.Key) then
      aRoot := aRoot^.Left
    else
      if TCmpRel.Less(aRoot^.Key, aKey) then
        aRoot := aRoot^.Right
      else
        break;
  Result := aRoot;
end;

class function TGBstUtil.GetLess(aRoot: PNode; const aKey: TKey): PNode;
begin
  Result := nil;
  while aRoot <> nil do
    if TCmpRel.Less(aRoot^.Key, aKey) then
      begin
        Result := aRoot;
        aRoot := aRoot^.Right;
      end
    else
      aRoot := aRoot^.Left;
end;

class function TGBstUtil.GetLessOrEqual(aRoot: PNode; const aKey: TKey): PNode;
begin
  Result := nil;
  while aRoot <> nil do
    if not TCmpRel.Less(aKey, aRoot^.Key) then
      begin
        Result := aRoot;
        aRoot := aRoot^.Right;
      end
    else
      aRoot := aRoot^.Left;
end;

class function TGBstUtil.GetGreater(aRoot: PNode; const aKey: TKey): PNode;
begin
  Result := nil;
  while aRoot <> nil do
    if TCmpRel.Less(aKey, aRoot^.Key) then
      begin
        Result := aRoot;
        aRoot := aRoot^.Left;
      end
    else
      aRoot := aRoot^.Right;
end;

class function TGBstUtil.GetGreaterOrEqual(aRoot: PNode; const aKey: TKey): PNode;
begin
  Result := nil;
  while aRoot <> nil do
    if not TCmpRel.Less(aRoot^.Key, aKey) then
      begin
        Result := aRoot;
        aRoot := aRoot^.Left;
      end
    else
      aRoot := aRoot^.Right;
end;

{ TGComparableBstUtil }

class function TGComparableBstUtil.FindKey(aRoot: PNode; const aKey: TKey): PNode;
begin
  while aRoot <> nil do
    if aKey < aRoot^.Key then
      aRoot := aRoot^.Left
    else
      if aRoot^.Key < aKey then
        aRoot := aRoot^.Right
      else
        break;
  Result := aRoot;
end;

class function TGComparableBstUtil.GetLess(aRoot: PNode; const aKey: TKey): PNode;
begin
  Result := nil;
  while aRoot <> nil do
    if aRoot^.Key < aKey then
      begin
        Result := aRoot;
        aRoot := aRoot^.Right;
      end
    else
      aRoot := aRoot^.Left;
end;

class function TGComparableBstUtil.GetLessOrEqual(aRoot: PNode; const aKey: TKey): PNode;
begin
  Result := nil;
  while aRoot <> nil do
    if not(aKey < aRoot^.Key) then
      begin
        Result := aRoot;
        aRoot := aRoot^.Right;
      end
    else
      aRoot := aRoot^.Left;
end;

class function TGComparableBstUtil.GetGreater(aRoot: PNode; const aKey: TKey): PNode;
begin
  Result := nil;
  while aRoot <> nil do
    if aKey < aRoot^.Key then
      begin
        Result := aRoot;
        aRoot := aRoot^.Left;
      end
    else
      aRoot := aRoot^.Right;
end;

class function TGComparableBstUtil.GetGreaterOrEqual(aRoot: PNode; const aKey: TKey): PNode;
begin
  Result := nil;
  while aRoot <> nil do
    if not(aRoot^.Key < aKey) then
      begin
        Result := aRoot;
        aRoot := aRoot^.Left;
      end
    else
      aRoot := aRoot^.Right;
end;

{ TGIndexedBstUtil }

class function TGIndexedBstUtil.GetNodeSize(aNode: PNode): SizeInt;
begin
  if aNode = nil then exit(0);
  Result := aNode^.Size;
end;

class function TGIndexedBstUtil.GetByIndex(aRoot: PNode; aIndex: SizeInt): PNode;
var
  LSize: SizeInt;
begin
  while aRoot <> nil do
    begin
      LSize := GetNodeSize(aRoot^.Left);
      if LSize < aIndex then
        begin
          aRoot := aRoot^.Right;
          aIndex -= Succ(LSize);
        end
      else
        if LSize > aIndex then
          aRoot := aRoot^.Left
        else
          exit(aRoot);
    end;
  Result := aRoot;
end;

class function TGIndexedBstUtil.GetKeyIndex(aRoot: PNode; const aKey: TKey): SizeInt;
var
  Pos: SizeInt = 0;
begin
  while aRoot <> nil do
    if TCmpRel.Less(aKey, aRoot^.Key) then
      aRoot := aRoot^.Left
    else
      if TCmpRel.Less(aRoot^.Key, aKey) then
        begin
          Pos += Succ(GetNodeSize(aRoot^.Left));
          aRoot := aRoot^.Right;
        end
      else
        exit(Pos + GetNodeSize(aRoot^.Left));
  Result := NULL_INDEX;
end;

{ TGCmpIndexedBstUtil }

class function TGCmpIndexedBstUtil.GetNodeSize(aNode: PNode): SizeInt;
begin
  if aNode = nil then exit(0);
  Result := aNode^.Size;
end;

class function TGCmpIndexedBstUtil.GetByIndex(aRoot: PNode; aIndex: SizeInt): PNode;
var
  LSize: SizeInt;
begin
  while aRoot <> nil do
    begin
      LSize := GetNodeSize(aRoot^.Left);
      if LSize < aIndex then
        begin
          aRoot := aRoot^.Right;
          aIndex -= Succ(LSize);
        end
      else
        if LSize > aIndex then
          aRoot := aRoot^.Left
        else
          exit(aRoot);
    end;
  Result := aRoot;
end;

class function TGCmpIndexedBstUtil.GetKeyIndex(aRoot: PNode; const aKey: TKey): SizeInt;
var
  Pos: SizeInt = 0;
begin
  while aRoot <> nil do
    if aKey < aRoot^.Key then
      aRoot := aRoot^.Left
    else
      if aRoot^.Key < aKey then
        begin
          Pos += Succ(GetNodeSize(aRoot^.Left));
          aRoot := aRoot^.Right;
        end
      else
        exit(Pos + GetNodeSize(aRoot^.Left));
  Result := NULL_INDEX;
end;

end.

