{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   The generic implementation of the conventional red-black tree.          *
*                                                                           *
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
unit lgRbTree;

{$mode objfpc}{$H+}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}
{$PACKRECORDS DEFAULT}
{$INLINE ON}

interface

uses
  SysUtils,
  lgUtils,
  lgBstUtils,
  {%H-}lgHelpers;

type
  TNodeColor = 0..1;
  TRbtState  = (rsConsistent,    //Ok
                rsConsecRed,     //Consecutive red links
                rsInvalidLink,   //Invalid BST link
                rsInvalidKey,    //Invalid BST key
                rsHBlackMismatch //Black height mismatch
                );
const
  BLACK: TNodeColor = 0;
  RED: TNodeColor   = 1;

type
  generic TGRbNode<TKey, TValue> = record
  private
  type
    PNode = ^TGRbNode;
  const
    PTR_MASK = High(SizeUInt) xor 1;
  var
    FLeft,
    FRight: PNode;
    FParent: SizeUInt;
    FKey: TKey;
    function  GetColor: TNodeColor; inline;
    function  GetLeft: PNode; inline;
    function  GetParent: PNode; inline;
    function  GetRight: PNode; inline;
    procedure SetColor(aValue: TNodeColor); inline;
    procedure SetLeft(aValue: PNode); inline;
    procedure SetParent(aValue: PNode); inline;
    procedure SetRight(aValue: PNode); inline;
    function  Successor: PNode;
    function  Predecessor: PNode;
    function  IsBlack: Boolean; inline;
    procedure MakeBlack; inline;
    function  IsRed: Boolean; inline;
    procedure MakeRed; inline;
    property  {%H-}LeftPtr: PNode write SetLeft;
    property  {%H-}RightPtr: PNode write SetRight;
    property  {%H-}ParentPtr: PNode write SetParent;
    property  {%H-}Color: TNodeColor read GetColor write SetColor;
  public
    Value: TValue;
    property  Left: PNode read GetLeft;
    property  Right: PNode read GetRight;
    property  Parent: PNode read GetParent;
    property  Key: TKey read FKey;
  end;

  { TGLiteRbTree implements the conventional red-black tree;
      functor TCmpRel (comparison relation) must provide:
        class function Less([const[ref]] L, R: TKey): Boolean;
    on assignment and when passed by value, the whole treap is copied }
  generic TGLiteRbTree<TKey, TValue, TCmpRel> = record
  public
  type
    TNode       = specialize TGRbNode<TKey, TValue>;
    PNode       = ^TNode;
    TUtil       = specialize TGBstUtil<TKey, TNode, TCmpRel>;
    TOnVisit    = TUtil.TOnVisit;
    TNestVisit  = TUtil.TNestVisit;
    TEntry      = specialize TGMapEntry<TKey, TValue>;
    TEntryArray = array of TEntry;


    TEnumerator = record
    private
      FCurr,
      FFirst: PNode;
      FInCycle: Boolean;
    public
      function  MoveNext: Boolean;
      procedure Reset; inline;
      property  Current: PNode read FCurr;
    end;

    TReverseEnumerator = record
      FCurr,
      FLast: PNode;
      FInCycle: Boolean;
    public
      function  MoveNext: Boolean;
      procedure Reset; inline;
      property  Current: PNode read FCurr;
    end;

  private
    FRoot: PNode;
    function  GetCount: SizeInt;
    function  GetHeight: SizeInt;
    function  FindNode(const aKey: TKey; out aParent: PNode): PNode;
    function  FindInsertPos(const aKey: TKey): PNode;
    procedure InsertNode(aNode: PNode);
    procedure InsertNodeAt(aNode, aParent: PNode);
    procedure DoRemoveNode(aNode: PNode);
    procedure InsertFixUp(aNode: PNode);
    procedure RemoveFixUp(aNode: PNode);
    procedure RotateLeft(aNode: PNode);
    procedure RotateRight(aNode: PNode);
    class function NewNode(const aKey: TKey): PNode; static; inline;
    class function CopyTree(aRoot: PNode): PNode; static;
    class function TestNodeState(aNode: PNode; var aState: TRbtState): SizeInt;  static;
    class operator Initialize(var rbt: TGLiteRbTree);
    class operator Finalize(var rbt: TGLiteRbTree);
    class operator Copy(constref aSrc: TGLiteRbTree; var aDst: TGLiteRbTree);
    class operator AddRef(var rbt: TGLiteRbTree); inline;
  public
    function  IsEmpty: Boolean; inline;
    function  GetEnumerator: TEnumerator;
    function  GetReverseEnumerator: TReverseEnumerator;
    function  GetEnumeratorAt(const aKey: TKey; aInclusive: Boolean): TEnumerator;
    function  ToArray: TEntryArray;           //O(N)
    procedure Clear;                          //O(N)
    function  Add(const aKey: TKey): PNode;
    function  FindOrAdd(const aKey: TKey; out aNode: PNode): Boolean;
    function  Find(const aKey: TKey): PNode;
    function  Remove(const aKey: TKey): Boolean;
    function  Remove(const aKey: TKey; out aValue: TValue): Boolean;
    procedure RemoveNode(aNode: PNode); inline;
    function  CheckState: TRbtState;
    property  Root: PNode read FRoot;
    property  Count: SizeInt read GetCount;   //O(N)
    property  Height: SizeInt read GetHeight; //O(N)
  end;

  { TGLiteComparableRbTree implements the conventional red-black tree;
    it assumes TKey has defined comparison operator <;
    on assignment and when passed by value, the whole treap is copied }
  generic TGLiteComparableRbTree<TKey, TValue> = record
  public
  type
    TNode       = specialize TGRbNode<TKey, TValue>;
    PNode       = ^TNode;
    TUtil       = specialize TGComparableBstUtil<TKey, TNode>;
    TOnVisit    = TUtil.TOnVisit;
    TNestVisit  = TUtil.TNestVisit;
    TEntry      = specialize TGMapEntry<TKey, TValue>;
    TEntryArray = array of TEntry;


    TEnumerator = record
    private
      FCurr,
      FFirst: PNode;
      FInCycle: Boolean;
    public
      function  MoveNext: Boolean;
      procedure Reset; inline;
      property  Current: PNode read FCurr;
    end;

    TReverseEnumerator = record
      FCurr,
      FLast: PNode;
      FInCycle: Boolean;
    public
      function  MoveNext: Boolean;
      procedure Reset; inline;
      property  Current: PNode read FCurr;
    end;

  private
    FRoot: PNode;
    function  GetCount: SizeInt;
    function  GetHeight: SizeInt;
    function  FindNode(const aKey: TKey; out aParent: PNode): PNode;
    function  FindInsertPos(const aKey: TKey): PNode;
    procedure InsertNode(aNode: PNode);
    procedure InsertNodeAt(aNode, aParent: PNode);
    procedure DoRemoveNode(aNode: PNode);
    procedure InsertFixUp(aNode: PNode);
    procedure RemoveFixUp(aNode: PNode);
    procedure RotateLeft(aNode: PNode);
    procedure RotateRight(aNode: PNode);
    class function NewNode(const aKey: TKey): PNode; static; inline;
    class function CopyTree(aRoot: PNode): PNode; static;
    class function TestNodeState(aNode: PNode; var aState: TRbtState): SizeInt;  static;
    class operator Initialize(var rbt: TGLiteComparableRbTree);
    class operator Finalize(var rbt: TGLiteComparableRbTree);
    class operator Copy(constref aSrc: TGLiteComparableRbTree; var aDst: TGLiteComparableRbTree);
    class operator AddRef(var rbt: TGLiteComparableRbTree); inline;
  public
    function  IsEmpty: Boolean; inline;
    function  GetEnumerator: TEnumerator;
    function  GetReverseEnumerator: TReverseEnumerator;
    function  GetEnumeratorAt(const aKey: TKey; aInclusive: Boolean): TEnumerator;
    function  ToArray: TEntryArray;           //O(N)
    procedure Clear;                          //O(N)
    function  Add(const aKey: TKey): PNode;
    function  FindOrAdd(const aKey: TKey; out aNode: PNode): Boolean;
    function  Find(const aKey: TKey): PNode;
    function  Remove(const aKey: TKey): Boolean;
    function  Remove(const aKey: TKey; out aValue: TValue): Boolean;
    procedure RemoveNode(aNode: PNode); inline;
    function  CheckState: TRbtState;
    property  Root: PNode read FRoot;
    property  Count: SizeInt read GetCount;   //O(N)
    property  Height: SizeInt read GetHeight; //O(N)
  end;

implementation
{$B-}{$COPERATORS ON}

{ TGRbNode }

function TGRbNode.GetColor: TNodeColor;
begin
  if @Self = nil then exit(0);
  Result := FParent and 1;
end;

function TGRbNode.GetLeft: PNode;
begin
  if @Self = nil then exit(nil);
  Result := FLeft;
end;

function TGRbNode.GetParent: PNode;
var
  r: SizeUInt absolute Result;
begin
  if @Self = nil then exit(nil);
  r := FParent and PTR_MASK;
end;

function TGRbNode.GetRight: PNode;
begin
  if @Self = nil then exit(nil);
  Result := FRight;
end;

procedure TGRbNode.SetColor(aValue: TNodeColor);
begin
  if @Self <> nil then
    FParent := (FParent and PTR_MASK) or aValue;
end;

procedure TGRbNode.SetLeft(aValue: PNode);
begin
  if @Self <> nil then
    FLeft := aValue;
end;

procedure TGRbNode.SetParent(aValue: PNode);
var
  p: SizeUInt absolute aValue;
begin
  if @Self <> nil then
    FParent := FParent and 1 or p;
end;

procedure TGRbNode.SetRight(aValue: PNode);
begin
  if @Self <> nil then
    FRight := aValue;
end;

function TGRbNode.Successor: PNode;
begin
  Result := FRight;
  if Result <> nil then
    while Result^.FLeft <> nil do
      Result := Result^.FLeft
  else
    begin
      Result := @Self;
      while (Result^.Parent <> nil) and (Result^.Parent^.FRight = Result) do
        Result := Result^.Parent;
      Result := Result^.Parent;
    end;
end;

function TGRbNode.Predecessor: PNode;
begin
  Result := FLeft;
  if Result <> nil then
    while Result^.FRight <> nil do
      Result := Result^.FRight
  else
    begin
      Result := @Self;
      while (Result^.Parent <> nil) and (Result^.Parent^.FLeft = Result) do
        Result := Result^.Parent;
      Result := Result^.Parent;
    end;
end;

function TGRbNode.IsBlack: Boolean;
begin
  if @Self = nil then exit(True);
  Result := not Boolean(FParent and 1);
end;

procedure TGRbNode.MakeBlack;
begin
  if @Self <> nil then
    FParent := FParent and PTR_MASK;
end;

function TGRbNode.IsRed: Boolean;
begin
  if @Self = nil then exit(False);
  Result := Boolean(FParent and 1);
end;

procedure TGRbNode.MakeRed;
begin
  if @Self <> nil then
    FParent := FParent or 1;
end;

{ TGLiteRbTree.TEnumerator }

function TGLiteRbTree.TEnumerator.MoveNext: Boolean;
var
  Node: PNode = nil;
begin
  if FCurr <> nil then
    Node := FCurr^.Successor
  else
    if not FInCycle then
      begin
        FInCycle := True;
        Node := FFirst;
      end;
  if Node <> nil then
    begin
      FCurr := Node;
      exit(True);
    end;
  Result := False;
end;

procedure TGLiteRbTree.TEnumerator.Reset;
begin
  FCurr := nil;
  FInCycle := False;
end;

{ TGLiteRbTree.TReverseEnumerator }

function TGLiteRbTree.TReverseEnumerator.MoveNext: Boolean;
var
  Node: PNode = nil;
begin
  if FCurr <> nil then
    Node := FCurr^.Predecessor
  else
    if not FInCycle then
      begin
        FInCycle := True;
        Node := FLast;
      end;
  if Node <> nil then
    begin
      FCurr := Node;
      exit(True);
    end;
  Result := False;
end;

procedure TGLiteRbTree.TReverseEnumerator.Reset;
begin
  FCurr := nil;
  FInCycle := False;
end;

{ TGLiteRbTree }

function TGLiteRbTree.GetCount: SizeInt;
begin
  if FRoot = nil then exit(0);
  Result := TUtil.GetTreeSize(FRoot);
end;

function TGLiteRbTree.GetHeight: SizeInt;
begin
  if FRoot = nil then exit(0);
  Result := TUtil.GetHeight(FRoot)
end;

function TGLiteRbTree.FindNode(const aKey: TKey; out aParent: PNode): PNode;
begin
  Result := Root;
  aParent := nil;
  while Result <> nil do
    begin
      aParent := Result;
      if TCmpRel.Less(aKey, Result^.Key) then
        Result := Result^.FLeft
      else
        if TCmpRel.Less(Result^.Key, aKey) then
          Result := Result^.FRight
        else
          break;
    end;
end;

function TGLiteRbTree.FindInsertPos(const aKey: TKey): PNode;
begin
  Result := Root;
  while Result <> nil do
    if TCmpRel.Less(aKey, Result^.Key) then
      begin
        if Result^.FLeft <> nil then
          Result := Result^.FLeft
        else
          break;
      end
    else
      begin
        if Result^.FRight <> nil then
          Result := Result^.FRight
        else
          break;
      end;
end;

procedure TGLiteRbTree.InsertNode(aNode: PNode);
var
  Parent: PNode;
begin
   if Root <> nil then
    begin
      Parent := FindInsertPos(aNode^.Key);
      aNode^.ParentPtr := Parent;
      if TCmpRel.Less(aNode^.Key, Parent^.Key) then
        Parent^.FLeft := aNode
      else
        Parent^.FRight := aNode;
      InsertFixUp(aNode);
    end
  else
    FRoot := aNode;
  Root^.MakeBlack;
end;

procedure TGLiteRbTree.InsertNodeAt(aNode, aParent: PNode);
begin
  if aParent <> nil then
    begin
      aNode^.ParentPtr := aParent;
      if TCmpRel.Less(aNode^.Key, aParent^.Key) then
        aParent^.FLeft := aNode
      else
        aParent^.FRight := aNode;
      InsertFixUp(aNode);
    end
  else
    FRoot := aNode;
  Root^.MakeBlack;
end;

procedure TGLiteRbTree.DoRemoveNode(aNode: PNode);
var
  Child, SuccNode, Parent: PNode;
begin
  if (aNode^.FLeft = nil) or (aNode^.FRight = nil) then
    begin
      SuccNode := aNode;
      if SuccNode^.FLeft <> nil then
        Child := SuccNode^.FLeft
      else
        Child := SuccNode^.FRight;
    end
  else
    begin
      SuccNode := aNode^.FRight;
      while SuccNode^.FLeft <> nil do
        SuccNode := SuccNode^.FLeft;
      Child := SuccNode^.FRight;
    end;

  Parent := SuccNode^.Parent;
  Child^.ParentPtr := Parent;
  if Parent <> nil then
    if SuccNode = Parent^.FLeft then
      Parent^.FLeft := Child
    else
      Parent^.FRight := Child
  else
    FRoot := Child;
  /////////////////////////////////
  if SuccNode^.IsBlack then
    RemoveFixUp(Child);
  /////////////////////////////////
  if SuccNode <> aNode then
    begin
      Parent := aNode^.Parent;
      if Parent <> nil then
        if Parent^.FLeft = aNode then
          Parent^.FLeft := SuccNode
        else
          Parent^.FRight := SuccNode;

      aNode^.FLeft^.ParentPtr := SuccNode;
      aNode^.FRight^.ParentPtr := SuccNode;
      SuccNode^.FLeft := aNode^.FLeft;
      SuccNode^.FRight := aNode^.FRight;
      SuccNode^.ParentPtr := Parent;
      SuccNode^.Color := aNode^.Color;

      if aNode = Root then
        FRoot := SuccNode;
    end;
  TUtil.FreeNode(aNode);
end;

procedure TGLiteRbTree.InsertFixUp(aNode: PNode);
var
  Uncle, Parent, Grandpa: PNode;
  IsLeft: Boolean;
begin
  while aNode <> Root do
    begin
      Parent := aNode^.Parent;
      if Parent^.IsBlack then
        break;
      Grandpa := Parent^.Parent;
      IsLeft := Parent = Grandpa^.FLeft;
      if IsLeft then
        Uncle := Grandpa^.FRight
      else
        Uncle := Grandpa^.FLeft;
      if Uncle^.IsRed then
        begin
          Parent^.MakeBlack;
          Uncle^.MakeBlack;
          Grandpa^.MakeRed;
          aNode := Grandpa;
        end
      else
        if IsLeft then
          begin
            if aNode = Parent^.FRight then
              begin
                aNode := Parent;
                RotateLeft(aNode);
                Parent := aNode^.Parent;
                Grandpa := Parent^.Parent;
              end;
            Parent^.MakeBlack;
            Grandpa^.MakeRed;
            RotateRight(Grandpa);
          end
        else
          begin
            if aNode = Parent^.FLeft then
              begin
                aNode := Parent;
                RotateRight(aNode);
                Parent := aNode^.Parent;
                Grandpa := Parent^.Parent;
              end;
            Parent^.MakeBlack;
            Grandpa^.MakeRed;
            RotateLeft(Grandpa);
          end;
    end;
end;

procedure TGLiteRbTree.RemoveFixUp(aNode: PNode);
var
  Sibling, SibLeft, SibRight, Parent: PNode;
  SibLeftColor, SibRightColor: TNodeColor;
  IsLeft: Boolean;
begin
  while (aNode^.Parent <> nil) and (aNode^.IsBlack) do
    begin
      Parent := aNode^.Parent;
      IsLeft := aNode = Parent^.Left;
      if IsLeft then
        Sibling := Parent^.Right
      else
        Sibling := Parent^.Left;
      if Sibling^.IsRed then
        begin
          Sibling^.MakeBlack;
          Parent^.MakeRed;
          if IsLeft then
            begin
              RotateLeft(Parent);
              Sibling := aNode^.Parent^.Right;
            end
          else
            begin
              RotateRight(Parent);
              Sibling := aNode^.Parent^.Left;
            end;
        end;
      SibLeft := Sibling^.Left;
      SibRight := Sibling^.Right;
      SibLeftColor := SibLeft^.Color;
      SibRightColor := SibRight^.Color;
      //if (SibLeftColor = BLACK) and (SibRightColor = BLACK) then
      if SibLeftColor or SibRightColor = BLACK then
        begin
          Sibling^.MakeRed;
          aNode := Parent;
        end
      else
        begin
          if IsLeft then
            begin
              if SibRightColor = BLACK then
                begin
                  SibLeft^.MakeBlack;
                  Sibling^.MakeRed;
                  RotateRight(Sibling);
                  Parent := aNode^.Parent;
                  Sibling := Parent^.Right;
                end;
              Sibling^.Color := Sibling^.Parent^.Color;
              Parent^.MakeBlack;
              SibRight^.MakeBlack;
              RotateLeft(Parent);
            end
          else
            begin
              if SibLeftColor = BLACK then
                begin
                  SibRight^.MakeBlack;
                  Sibling^.MakeRed;
                  RotateLeft(Sibling);
                  Parent := aNode^.Parent;
                  Sibling := Parent^.Left;
                end;
              Sibling^.Color := Parent^.Color;
              Parent^.MakeBlack;
              SibLeft^.MakeBlack;
              RotateRight(Parent);
            end;
          aNode := Root;
        end;
    end;
  aNode^.MakeBlack;
end;

procedure TGLiteRbTree.RotateLeft(aNode: PNode);
var
  R, Parent: PNode;
begin
  R := aNode^.FRight;
  aNode^.FRight := R^.FLeft;
  if R^.FLeft <> nil then
    R^.FLeft^.ParentPtr := aNode;
  Parent := aNode^.Parent;
  if R <> nil then
    R^.ParentPtr := Parent;
  if Parent <> nil then
    if aNode = Parent^.FLeft then
      Parent^.FLeft := R
    else
      Parent^.FRight := R
  else
    FRoot := R;
  R^.FLeft := aNode;
  if aNode <> nil then
    aNode^.ParentPtr := R;
end;

procedure TGLiteRbTree.RotateRight(aNode: PNode);
var
  L, Parent: PNode;
begin
  L := aNode^.FLeft;
  aNode^.FLeft := L^.FRight;
  if L^.FRight <> nil then
    L^.FRight^.ParentPtr := aNode;
  Parent := aNode^.Parent;
  if L <> nil then
    L^.ParentPtr := Parent;
  if Parent <> nil then
    if aNode = Parent^.FRight then
      Parent^.FRight := L
    else
      Parent^.FLeft := L
  else
    FRoot := L;
  L^.FRight := aNode;
  if aNode <> nil then
    aNode^.ParentPtr := L;
end;

class function TGLiteRbTree.NewNode(const aKey: TKey): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.FKey := aKey;
  Result^.FParent := RED;
end;

class function TGLiteRbTree.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteRbTree;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        Tmp.Add(aNode^.Key)^.Value := aNode^.Value;
        Visit(aNode^.Right);
      end;
  end;
begin
  Tmp.Clear;
  if aRoot <> nil then
    begin
      Visit(aRoot);
      Result := Tmp.FRoot;
      Tmp.FRoot := nil;
    end
  else
    Result := nil;
end;

class function TGLiteRbTree.TestNodeState(aNode: PNode; var aState: TRbtState): SizeInt;
var
  LHeight, RHeight: SizeInt;
begin
  if (aNode = nil) or (aState <> rsConsistent) then exit(0);
  if aNode^.IsRed then
    if aNode^.Left^.IsRed or aNode^.Right^.IsRed then
      begin
        aState := rsConsecRed;
        exit(0);
      end;
  if aNode^.Left <> nil then
    begin
      if aNode^.Left^.Parent <> aNode then
        begin
          aState := rsInvalidLink;
          exit(0);
        end;
      if not TCmpRel.Less(aNode^.Left^.Key, aNode^.Key) then
        begin
          aState := rsInvalidKey;
          exit(0);
        end;
    end;
  if aNode^.Right <> nil then
    begin
      if aNode^.Right^.Parent <> aNode then
        begin
          aState := rsInvalidLink;
          exit(0);
        end;
      if TCmpRel.Less(aNode^.Right^.Key, aNode^.Key) then
        begin
          aState := rsInvalidKey;
          exit(0);
        end;
    end;
  LHeight := TestNodeState(aNode^.Left, aState);
  RHeight := TestNodeState(aNode^.Right, aState);
  if aState <> rsConsistent then exit(0);
  if LHeight <> RHeight then
    begin
      aState := rsHBlackMismatch;
      exit(0);
    end;
  Result := LHeight + Ord(aNode^.IsBlack);
end;

class operator TGLiteRbTree.Initialize(var rbt: TGLiteRbTree);
begin
  rbt.FRoot := nil;
end;

class operator TGLiteRbTree.Finalize(var rbt: TGLiteRbTree);
begin
  rbt.Clear;
end;

class operator TGLiteRbTree.Copy(constref aSrc: TGLiteRbTree; var aDst: TGLiteRbTree);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteRbTree.AddRef(var rbt: TGLiteRbTree);
begin
  if rbt.FRoot <> nil then
    rbt.FRoot := CopyTree(rbt.FRoot);
end;

function TGLiteRbTree.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

function TGLiteRbTree.GetEnumerator: TEnumerator;
begin
  Result.FCurr := nil;
  Result.FFirst := TUtil.GetLowest(FRoot);
  Result.FInCycle := False;
end;

function TGLiteRbTree.GetReverseEnumerator: TReverseEnumerator;
begin
  Result.FCurr := nil;
  Result.FLast := TUtil.GetHighest(FRoot);
  Result.FInCycle := False;
end;

function TGLiteRbTree.GetEnumeratorAt(const aKey: TKey; aInclusive: Boolean): TEnumerator;
begin
  Result.FCurr := nil;
  if aInclusive then
    Result.FFirst := TUtil.GetGreaterOrEqual(FRoot, aKey)
  else
    Result.FFirst := TUtil.GetGreater(FRoot, aKey);
  Result.FInCycle := False;
end;

function TGLiteRbTree.ToArray: TEntryArray;
var
  a: TEntryArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode = nil then exit;
    Visit(aNode^.FLeft);
    if System.Length(a) = I then
      System.SetLength(a, I * 2);
    a[I] := TEntry.Create(aNode^.Key, aNode^.Value);
    Inc(I);
    Visit(aNode^.FRight);
  end;
begin
  if FRoot <> nil then
    begin
      System.SetLength(a, ARRAY_INITIAL_SIZE);
      Visit(FRoot);
      System.SetLength(a, I);
    end;
  Result := a;
end;

procedure TGLiteRbTree.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteRbTree.Add(const aKey: TKey): PNode;
var
  Parent: PNode;
begin
  if FindNode(aKey, Parent) = nil then
    begin
      Result := NewNode(aKey);
      InsertNodeAt(Result, Parent);
      exit;
    end;
  Result := nil;
end;

function TGLiteRbTree.FindOrAdd(const aKey: TKey; out aNode: PNode): Boolean;
var
  Parent: PNode;
begin
  aNode := FindNode(aKey, Parent);
  Result := aNode <> nil;
  if not Result then
    begin
      aNode := NewNode(aKey);
      InsertNodeAt(aNode, Parent);
    end;
end;

function TGLiteRbTree.Find(const aKey: TKey): PNode;
begin
  if Root <> nil then
    exit(TUtil.FindKey(Root, aKey));
  Result := nil;
end;

function TGLiteRbTree.Remove(const aKey: TKey): Boolean;
var
  Node: PNode;
begin
  Node := Find(aKey);
  if Node <> nil then
    begin
      DoRemoveNode(Node);
      exit(True);
    end;
  Result := False;
end;

function TGLiteRbTree.Remove(const aKey: TKey; out aValue: TValue): Boolean;
var
  Node: PNode;
begin
  Node := Find(aKey);
  if Node <> nil then
    begin
      aValue := Node^.Value;
      DoRemoveNode(Node);
      exit(True);
    end;
  Result := False;
end;

procedure TGLiteRbTree.RemoveNode(aNode: PNode);
begin
  if aNode <> nil then
    DoRemoveNode(aNode);
end;

function TGLiteRbTree.CheckState: TRbtState;
begin
  Result := rsConsistent;
  if FRoot <> nil then
    TestNodeState(FRoot, Result);
end;




{ TGLiteComparableRbTree.TEnumerator }

function TGLiteComparableRbTree.TEnumerator.MoveNext: Boolean;
var
  Node: PNode = nil;
begin
  if FCurr <> nil then
    Node := FCurr^.Successor
  else
    if not FInCycle then
      begin
        FInCycle := True;
        Node := FFirst;
      end;
  if Node <> nil then
    begin
      FCurr := Node;
      exit(True);
    end;
  Result := False;
end;

procedure TGLiteComparableRbTree.TEnumerator.Reset;
begin
  FCurr := nil;
  FInCycle := False;
end;

{ TGLiteComparableRbTree.TReverseEnumerator }

function TGLiteComparableRbTree.TReverseEnumerator.MoveNext: Boolean;
var
  Node: PNode = nil;
begin
  if FCurr <> nil then
    Node := FCurr^.Predecessor
  else
    if not FInCycle then
      begin
        FInCycle := True;
        Node := FLast;
      end;
  if Node <> nil then
    begin
      FCurr := Node;
      exit(True);
    end;
  Result := False;
end;

procedure TGLiteComparableRbTree.TReverseEnumerator.Reset;
begin
  FCurr := nil;
  FInCycle := False;
end;

{ TGLiteComparableRbTree }

function TGLiteComparableRbTree.GetCount: SizeInt;
begin
  if FRoot = nil then exit(0);
  Result := TUtil.GetTreeSize(FRoot);
end;

function TGLiteComparableRbTree.GetHeight: SizeInt;
begin
  if FRoot = nil then exit(0);
  Result := TUtil.GetHeight(FRoot)
end;

function TGLiteComparableRbTree.FindNode(const aKey: TKey; out aParent: PNode): PNode;
begin
  Result := Root;
  aParent := nil;
  while Result <> nil do
    begin
      aParent := Result;
      if aKey < Result^.Key then
        Result := Result^.FLeft
      else
        if Result^.Key < aKey then
          Result := Result^.FRight
        else
          break;
    end;
end;

function TGLiteComparableRbTree.FindInsertPos(const aKey: TKey): PNode;
begin
  Result := Root;
  while Result <> nil do
    if aKey < Result^.Key then
      begin
        if Result^.FLeft <> nil then
          Result := Result^.FLeft
        else
          break;
      end
    else
      begin
        if Result^.FRight <> nil then
          Result := Result^.FRight
        else
          break;
      end;
end;

procedure TGLiteComparableRbTree.InsertNode(aNode: PNode);
var
  Parent: PNode;
begin
   if Root <> nil then
    begin
      Parent := FindInsertPos(aNode^.Key);
      aNode^.ParentPtr := Parent;
      if aNode^.Key < Parent^.Key then
        Parent^.FLeft := aNode
      else
        Parent^.FRight := aNode;
      InsertFixUp(aNode);
    end
  else
    FRoot := aNode;
  Root^.MakeBlack;
end;

procedure TGLiteComparableRbTree.InsertNodeAt(aNode, aParent: PNode);
begin
  if aParent <> nil then
    begin
      aNode^.ParentPtr := aParent;
      if aNode^.Key < aParent^.Key then
        aParent^.FLeft := aNode
      else
        aParent^.FRight := aNode;
      InsertFixUp(aNode);
    end
  else
    FRoot := aNode;
  Root^.MakeBlack;
end;

procedure TGLiteComparableRbTree.DoRemoveNode(aNode: PNode);
var
  Child, SuccNode, Parent: PNode;
begin
  if (aNode^.FLeft = nil) or (aNode^.FRight = nil) then
    begin
      SuccNode := aNode;
      if SuccNode^.FLeft <> nil then
        Child := SuccNode^.FLeft
      else
        Child := SuccNode^.FRight;
    end
  else
    begin
      SuccNode := aNode^.FRight;
      while SuccNode^.FLeft <> nil do
        SuccNode := SuccNode^.FLeft;
      Child := SuccNode^.FRight;
    end;

  Parent := SuccNode^.Parent;
  Child^.ParentPtr := Parent;
  if Parent <> nil then
    if SuccNode = Parent^.FLeft then
      Parent^.FLeft := Child
    else
      Parent^.FRight := Child
  else
    FRoot := Child;
  /////////////////////////////////
  if SuccNode^.IsBlack then
    RemoveFixUp(Child);
  /////////////////////////////////
  if SuccNode <> aNode then
    begin
      Parent := aNode^.Parent;
      if Parent <> nil then
        if Parent^.FLeft = aNode then
          Parent^.FLeft := SuccNode
        else
          Parent^.FRight := SuccNode;

      aNode^.FLeft^.ParentPtr := SuccNode;
      aNode^.FRight^.ParentPtr := SuccNode;
      SuccNode^.FLeft := aNode^.FLeft;
      SuccNode^.FRight := aNode^.FRight;
      SuccNode^.ParentPtr := Parent;
      SuccNode^.Color := aNode^.Color;

      if aNode = Root then
        FRoot := SuccNode;
    end;
  TUtil.FreeNode(aNode);
end;

procedure TGLiteComparableRbTree.InsertFixUp(aNode: PNode);
var
  Uncle, Parent, Grandpa: PNode;
  IsLeft: Boolean;
begin
  while aNode <> Root do
    begin
      Parent := aNode^.Parent;
      if Parent^.IsBlack then
        break;
      Grandpa := Parent^.Parent;
      IsLeft := Parent = Grandpa^.FLeft;
      if IsLeft then
        Uncle := Grandpa^.FRight
      else
        Uncle := Grandpa^.FLeft;
      if Uncle^.IsRed then
        begin
          Parent^.MakeBlack;
          Uncle^.MakeBlack;
          Grandpa^.MakeRed;
          aNode := Grandpa;
        end
      else
        if IsLeft then
          begin
            if aNode = Parent^.FRight then
              begin
                aNode := Parent;
                RotateLeft(aNode);
                Parent := aNode^.Parent;
                Grandpa := Parent^.Parent;
              end;
            Parent^.MakeBlack;
            Grandpa^.MakeRed;
            RotateRight(Grandpa);
          end
        else
          begin
            if aNode = Parent^.FLeft then
              begin
                aNode := Parent;
                RotateRight(aNode);
                Parent := aNode^.Parent;
                Grandpa := Parent^.Parent;
              end;
            Parent^.MakeBlack;
            Grandpa^.MakeRed;
            RotateLeft(Grandpa);
          end;
    end;
end;

procedure TGLiteComparableRbTree.RemoveFixUp(aNode: PNode);
var
  Sibling, SibLeft, SibRight, Parent: PNode;
  SibLeftColor, SibRightColor: TNodeColor;
  IsLeft: Boolean;
begin
  while (aNode^.Parent <> nil) and (aNode^.IsBlack) do
    begin
      Parent := aNode^.Parent;
      IsLeft := aNode = Parent^.Left;
      if IsLeft then
        Sibling := Parent^.Right
      else
        Sibling := Parent^.Left;
      if Sibling^.IsRed then
        begin
          Sibling^.MakeBlack;
          Parent^.MakeRed;
          if IsLeft then
            begin
              RotateLeft(Parent);
              Sibling := aNode^.Parent^.Right;
            end
          else
            begin
              RotateRight(Parent);
              Sibling := aNode^.Parent^.Left;
            end;
        end;
      SibLeft := Sibling^.Left;
      SibRight := Sibling^.Right;
      SibLeftColor := SibLeft^.Color;
      SibRightColor := SibRight^.Color;
      //if (SibLeftColor = BLACK) and (SibRightColor = BLACK) then
      if SibLeftColor or SibRightColor = BLACK then
        begin
          Sibling^.MakeRed;
          aNode := Parent;
        end
      else
        begin
          if IsLeft then
            begin
              if SibRightColor = BLACK then
                begin
                  SibLeft^.MakeBlack;
                  Sibling^.MakeRed;
                  RotateRight(Sibling);
                  Parent := aNode^.Parent;
                  Sibling := Parent^.Right;
                end;
              Sibling^.Color := Sibling^.Parent^.Color;
              Parent^.MakeBlack;
              SibRight^.MakeBlack;
              RotateLeft(Parent);
            end
          else
            begin
              if SibLeftColor = BLACK then
                begin
                  SibRight^.MakeBlack;
                  Sibling^.MakeRed;
                  RotateLeft(Sibling);
                  Parent := aNode^.Parent;
                  Sibling := Parent^.Left;
                end;
              Sibling^.Color := Parent^.Color;
              Parent^.MakeBlack;
              SibLeft^.MakeBlack;
              RotateRight(Parent);
            end;
          aNode := Root;
        end;
    end;
  aNode^.MakeBlack;
end;

procedure TGLiteComparableRbTree.RotateLeft(aNode: PNode);
var
  R, Parent: PNode;
begin
  R := aNode^.FRight;
  aNode^.FRight := R^.FLeft;
  if R^.FLeft <> nil then
    R^.FLeft^.ParentPtr := aNode;
  Parent := aNode^.Parent;
  if R <> nil then
    R^.ParentPtr := Parent;
  if Parent <> nil then
    if aNode = Parent^.FLeft then
      Parent^.FLeft := R
    else
      Parent^.FRight := R
  else
    FRoot := R;
  R^.FLeft := aNode;
  if aNode <> nil then
    aNode^.ParentPtr := R;
end;

procedure TGLiteComparableRbTree.RotateRight(aNode: PNode);
var
  L, Parent: PNode;
begin
  L := aNode^.FLeft;
  aNode^.FLeft := L^.FRight;
  if L^.FRight <> nil then
    L^.FRight^.ParentPtr := aNode;
  Parent := aNode^.Parent;
  if L <> nil then
    L^.ParentPtr := Parent;
  if Parent <> nil then
    if aNode = Parent^.FRight then
      Parent^.FRight := L
    else
      Parent^.FLeft := L
  else
    FRoot := L;
  L^.FRight := aNode;
  if aNode <> nil then
    aNode^.ParentPtr := L;
end;

class function TGLiteComparableRbTree.NewNode(const aKey: TKey): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.FKey := aKey;
  Result^.FParent := RED;
end;

class function TGLiteComparableRbTree.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteComparableRbTree;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        Tmp.Add(aNode^.Key)^.Value := aNode^.Value;
        Visit(aNode^.Right);
      end;
  end;
begin
  Tmp.Clear;
  if aRoot <> nil then
    begin
      Visit(aRoot);
      Result := Tmp.FRoot;
      Tmp.FRoot := nil;
    end
  else
    Result := nil;
end;

class function TGLiteComparableRbTree.TestNodeState(aNode: PNode; var aState: TRbtState): SizeInt;
var
  LHeight, RHeight: SizeInt;
begin
  if (aNode = nil) or (aState <> rsConsistent) then exit(0);
  if aNode^.IsRed then
    if aNode^.Left^.IsRed or aNode^.Right^.IsRed then
      begin
        aState := rsConsecRed;
        exit(0);
      end;
  if aNode^.Left <> nil then
    begin
      if aNode^.Left^.Parent <> aNode then
        begin
          aState := rsInvalidLink;
          exit(0);
        end;
      if not(aNode^.Left^.Key < aNode^.Key) then
        begin
          aState := rsInvalidKey;
          exit(0);
        end;
    end;
  if aNode^.Right <> nil then
    begin
      if aNode^.Right^.Parent <> aNode then
        begin
          aState := rsInvalidLink;
          exit(0);
        end;
      if aNode^.Right^.Key < aNode^.Key then
        begin
          aState := rsInvalidKey;
          exit(0);
        end;
    end;
  LHeight := TestNodeState(aNode^.Left, aState);
  RHeight := TestNodeState(aNode^.Right, aState);
  if aState <> rsConsistent then exit(0);
  if LHeight <> RHeight then
    begin
      aState := rsHBlackMismatch;
      exit(0);
    end;
  Result := LHeight + Ord(aNode^.IsBlack);
end;

class operator TGLiteComparableRbTree.Initialize(var rbt: TGLiteComparableRbTree);
begin
  rbt.FRoot := nil;
end;

class operator TGLiteComparableRbTree.Finalize(var rbt: TGLiteComparableRbTree);
begin
  rbt.Clear;
end;

class operator TGLiteComparableRbTree.Copy(constref aSrc: TGLiteComparableRbTree;
  var aDst: TGLiteComparableRbTree);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteComparableRbTree.AddRef(var rbt: TGLiteComparableRbTree);
begin
  if rbt.FRoot <> nil then
    rbt.FRoot := CopyTree(rbt.FRoot);
end;

function TGLiteComparableRbTree.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

function TGLiteComparableRbTree.GetEnumerator: TEnumerator;
begin
  Result.FCurr := nil;
  Result.FFirst := TUtil.GetLowest(FRoot);
  Result.FInCycle := False;
end;

function TGLiteComparableRbTree.GetReverseEnumerator: TReverseEnumerator;
begin
  Result.FCurr := nil;
  Result.FLast := TUtil.GetHighest(FRoot);
  Result.FInCycle := False;
end;

function TGLiteComparableRbTree.GetEnumeratorAt(const aKey: TKey; aInclusive: Boolean): TEnumerator;
begin
  Result.FCurr := nil;
  if aInclusive then
    Result.FFirst := TUtil.GetGreaterOrEqual(FRoot, aKey)
  else
    Result.FFirst := TUtil.GetGreater(FRoot, aKey);
  Result.FInCycle := False;
end;

function TGLiteComparableRbTree.ToArray: TEntryArray;
var
  a: TEntryArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode = nil then exit;
    Visit(aNode^.FLeft);
    if System.Length(a) = I then
      System.SetLength(a, I * 2);
    a[I] := TEntry.Create(aNode^.Key, aNode^.Value);
    Inc(I);
    Visit(aNode^.FRight);
  end;
begin
  if FRoot <> nil then
    begin
      System.SetLength(a, ARRAY_INITIAL_SIZE);
      Visit(FRoot);
      System.SetLength(a, I);
    end;
  Result := a;
end;

procedure TGLiteComparableRbTree.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteComparableRbTree.Add(const aKey: TKey): PNode;
var
  Parent: PNode;
begin
  if FindNode(aKey, Parent) = nil then
    begin
      Result := NewNode(aKey);
      InsertNodeAt(Result, Parent);
      exit;
    end;
  Result := nil;
end;

function TGLiteComparableRbTree.FindOrAdd(const aKey: TKey; out aNode: PNode): Boolean;
var
  Parent: PNode;
begin
  aNode := FindNode(aKey, Parent);
  Result := aNode <> nil;
  if not Result then
    begin
      aNode := NewNode(aKey);
      InsertNodeAt(aNode, Parent);
    end;
end;

function TGLiteComparableRbTree.Find(const aKey: TKey): PNode;
begin
  if Root <> nil then
    exit(TUtil.FindKey(Root, aKey));
  Result := nil;
end;

function TGLiteComparableRbTree.Remove(const aKey: TKey): Boolean;
var
  Node: PNode;
begin
  Node := Find(aKey);
  if Node <> nil then
    begin
      DoRemoveNode(Node);
      exit(True);
    end;
  Result := False;
end;

function TGLiteComparableRbTree.Remove(const aKey: TKey; out aValue: TValue): Boolean;
var
  Node: PNode;
begin
  Node := Find(aKey);
  if Node <> nil then
    begin
      aValue := Node^.Value;
      DoRemoveNode(Node);
      exit(True);
    end;
  Result := False;
end;

procedure TGLiteComparableRbTree.RemoveNode(aNode: PNode);
begin
  if aNode <> nil then
    DoRemoveNode(aNode);
end;

function TGLiteComparableRbTree.CheckState: TRbtState;
begin
  Result := rsConsistent;
  if FRoot <> nil then
    TestNodeState(FRoot, Result);
end;

end.

