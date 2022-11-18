{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic rooted tree implementation.                                     *
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
unit lgRootTree;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}

interface
   
uses
  SysUtils,
  lgUtils,
  {%H-}lgHelpers,
  lgStack,
  lgQueue;

type
  { TGLiteRootedTree }
  generic TGLiteRootedTree<T> = record
  private
  type
    PNode = ^TNode;
    TNode = record
      Parent,
      Child,
      Sibling: PNode;
      Value: T;
    end;

    TVisitNode = record
      Node: PNode;
      Visited: Boolean;
      constructor Create(aNode: PNode);
    end;

    TNodePair = record
      Node,
      NodeCopy: PNode;
      constructor Create(aNode, aCopy: PNode);
    end;

    TLvlNode = record
      Node: PNode;
      Level: SizeInt;
      constructor Create(aNode: PNode; aLevel: SizeInt);
    end;

    PVisitNode  = ^TVisitNode;
    TVisitStack = specialize TGLiteStack<TVisitNode>;
    TNodeStack  = specialize TGLiteStack<PNode>;
    TQueue      = specialize TGLiteQueue<PNode>;
    TPairQueue  = specialize TGLiteQueue<TNodePair>;
    TLvlQueue   = specialize TGLiteQueue<TLvlNode>;

  public
  type
    PValue = ^T;
    TArray = array of T;

    TTreeNode = record
    private
    type
      TNodeEvent      = procedure(aNode: TTreeNode) of object;
      TNestNodeEvent  = procedure(aNode: TTreeNode) is nested;
    var
      FNode: PNode;
      function  GetValue: T; inline;
      function  GetMutValue: PValue; inline;
      procedure SetValue(const aValue: T); inline;
      function  GetRoot: TTreeNode;
      function  GetDepth(out aRoot: PNode): SizeInt;
      class function  AddNodeChild(aNode, aChild: PNode): PNode;  static;
      class function  FindLastNodeChild(aNode: PNode; out aChild: PNode): Boolean;  static;
      class function  AddNodeLastChild(aNode, aChild: PNode): PNode;  static;
      class procedure CutFromTree(aNode: PNode); static;
      class operator := (aNode: PNode): TTreeNode; inline;
    public
    type
      TEnumerator = record
      private
        FQueue: TQueue;
        FCurrent: PNode;
        function GetCurrent: TTreeNode; inline;
      public
        function MoveNext: Boolean;
        property Current: TTreeNode read GetCurrent;
      end;

      TAncestorEnumerator = record
      private
        FCurrent,
        FNext: PNode;
        function GetCurrent: TTreeNode; inline;
      public
        function MoveNext: Boolean; inline;
        property Current: TTreeNode read GetCurrent;
      end;

      TAncestors = record
      private
        FNode: PNode;
      public
        function GetEnumerator: TAncestorEnumerator; inline;
        function ToArray: TArray;
      end;

      TChildEnumerator = record
      private
        FCurrent,
        FNext: PNode;
        function GetCurrent: TTreeNode; inline;
      public
        function MoveNext: Boolean;
        property Current: TTreeNode read GetCurrent;
      end;

      TChildren = record
      private
        FNode: PNode;
      public
        function GetEnumerator: TChildEnumerator; inline;
        function ToArray: TArray;
      end;

      TPreordEnumerator = record
      private
        FStack: TNodeStack;
        FCurrent: PNode;
        function  GetCurrent: TTreeNode; inline;
      public
        function  MoveNext: Boolean;
        property  Current: TTreeNode read GetCurrent;
      end;

      TPreordTraversal = record
      private
        FNode: PNode;
      public
        function GetEnumerator: TPreordEnumerator;
        function ToArray: TArray;
      end;

      TPostordEnumerator = record
      private
        FStack: TVisitStack;
        FCurrent: PNode;
        function GetCurrent: TTreeNode; inline;
      public
        function MoveNext: Boolean;
        property Current: TTreeNode read GetCurrent;
      end;

      TPostordTraversal = record
      private
        FNode: PNode;
      public
        function GetEnumerator: TPostordEnumerator;
        function ToArray: TArray;
      end;

    private
    type
      TEnumNode = record
        Node: PNode;
        Enum: TChildEnumerator;
        Visited: Boolean;
        constructor Create(aNode: PNode);
      end;
      PEnumNode  = ^TEnumNode;
      TEnumStack = specialize TGLiteStack<TEnumNode>;

      function  GetChildEnumerator: TChildEnumerator; inline;
    public
      class operator = (L, R: TTreeNode): Boolean; inline;
    { default enumerator lists the node subtree in BFS order(level by level) }
      function GetEnumerator: TEnumerator; inline;
    { returns True if an internal node pointer is assigned }
      function Assigned: Boolean; inline;
    { sets the node pointer to nil }
      procedure Clear; inline;
    { returns True if the node is the root of some tree }
      function IsRoot: Boolean; inline;
    { returns True if the node has no children }
      function IsLeaf: Boolean; inline;
    { returns the number of children }
      function Degree: SizeInt;
    { returns the distance between a node and the root(the root is at level 0) }
      function Level: SizeInt; inline;
    { returns the number of edges on the longest path between a node and a descendant leaf }
      function Height: SizeInt;
    { returns the number of nodes at the node level and its level in aLevel }
      function Width(out aLevel: SizeInt): SizeInt;
    { returns the number of nodes in the node subtree }
      function Size: SizeInt;
      function HasParent: Boolean; inline;
      function HasChildren: Boolean; inline;
      function HasSibling: Boolean; inline;
      function GetParent(out aParent: TTreeNode): Boolean; inline;
    { returns True and the leftmost child of the node in aChild if the node has children }
      function GetFirstChild(out aChild: TTreeNode): Boolean; inline;
    { returns True and the rightmost child of the node in aChild if the node has children }
      function GetLastChild(out aChild: TTreeNode): Boolean; inline;
      function GetSibling(out aSibling: TTreeNode): Boolean; inline;
    { returns True if the node and aNode belong to the same tree }
      function InSameTree(aNode: TTreeNode): Boolean; inline;
    { returns the number of edges along the shortest path between node and aNode,
      or -1 if aNode belongs to another tree }
      function DistanceFrom(aNode: TTreeNode): SizeInt;
    { returns True if the node is reachable by repeated proceeding from aNode to its childs }
      function IsDescendantOf(aNode: TTreeNode): Boolean;
    { returns True if aNode is reachable by repeated proceeding from the node to its childs }
      function IsAncestorOf(aNode: TTreeNode): Boolean;
    { returns True and lowest common ancestor of the node and aNode in aLca
      if the node and aNode belong to the same tree, and neither the node nor aNode is root,
      otherwise returns False }
      function GetLca(aNode: TTreeNode; out aLca: TTreeNode): Boolean;
    { adds a new leftmost child node with a default value and returns the added node }
      function AddChild: TTreeNode; inline;
    { adds a new leftmost child node with value aValue and returns the added node }
      function AddChild(const aValue: T): TTreeNode; inline;
    { adds the root of aTree as the leftmost child node and returns the added node;
      aTree must be non-empty and becomes empty after adding }
      function AddChildTree(var aTree: TGLiteRootedTree): TTreeNode; inline;
    { adds a new rightmost child node with a default value and returns the added node }
      function AddLastChild: TTreeNode; inline;
    { adds a new rightmost child node with value aValue and returns the added node }
      function AddLastChild(const aValue: T): TTreeNode; inline;
    { adds the root of aTree as the rightmost child node and returns the added node;
      aTree must be non-empty and becomes empty after adding }
      function AddLastChildTree(var aTree: TGLiteRootedTree): TTreeNode; inline;
    { returns True and a tree with this node as the root in aTree if the node
      is not the root of any tree, otherwise returns False and an empty tree }
      function Extract(out aTree: TGLiteRootedTree): Boolean;
    { lists ancestors of the node, it is possible modify/remove current node during iteration}
      function Ancestors: TAncestors; inline;
    { lists children of the node, it is possible modify/remove current node during iteration }
      function Children: TChildren; inline;
    { lists the node subtree in pre-order sequence }
      function PreorderTraversal: TPreordTraversal; inline;
    { lists the node subtree in post-order sequence;
      it is possible modify/remove current node during iteration }
      function PostorderTraversal: TPostordTraversal; inline;
    { lists the node subtree in bread-first search order; returns the number of nodes found;
      aOnWhite is called when a node is discovered(if assigned),
      aOnGray is called when a node is visited(if assigned),
      aOnBlack is called when a node is done(if assigned) }
      function BfsTraversal(aOnWhite, aOnGray, aOnBlack: TNodeEvent): SizeInt;
    { ..... }
      function BfsTraversal(aOnWhite, aOnGray, aOnBlack: TNestNodeEvent): SizeInt;
    { lists the node subtree in depth-first right-to-left search order;
      returns the number of nodes found;
      aOnWhite is called when a node is discovered(if assigned),
      aOnGray is called when a node is visited(if assigned),
      aOnBlack is called when a node is done(if assigned) }
      function DfsTraversalR2L(aOnWhite, aOnGray, aOnBlack: TNodeEvent): SizeInt;
    { ..... }
      function DfsTraversalR2L(aOnWhite, aOnGray, aOnBlack: TNestNodeEvent): SizeInt;
    { lists the node subtree in depth-first left-to-right search order;
      returns the number of nodes found;
      aOnWhite is called when a node is discovered(if assigned),
      aOnGray is called when a node is visited(if assigned),
      aOnBlack is called when a node is done(if assigned) }
      function DfsTraversalL2R(aOnWhite, aOnGray, aOnBlack: TNodeEvent): SizeInt;
    { ..... }
      function DfsTraversalL2R(aOnWhite, aOnGray, aOnBlack: TNestNodeEvent): SizeInt;
      property Value: T read GetValue write SetValue;
      property MutValue: PValue read GetMutValue;
    { the root of the tree to which the node belongs }
      property Root: TTreeNode read GetRoot;
    end;

  public
  type
    TNodeEvent      = TTreeNode.TNodeEvent;
    TNestNodeEvent  = TTreeNode.TNestNodeEvent;

  private
    FRoot: PNode;
    FOwnsRoot: Boolean;
    procedure AssignRoot(aNode: PNode);
    function GetRoot: TTreeNode;
    function GetCount: SizeInt; inline;
    function RemoveNode(aNode: TTreeNode; aOnRemove: TNestNodeEvent): SizeInt;
    function DoClear: SizeInt;
    class function DoRemoveNode(aNode: PNode): SizeInt; static;
    class function DoRemoveNode(aNode: PNode; aBeforeRemove: TNestNodeEvent): SizeInt; static;
    class function NewNode(const aValue: T): PNode; static;
    class function CreateNode: PNode; static;
    class procedure FreeNode(aNode: PNode); static;
    class function SubTreeCopy(aNode: PNode; out aNodeCopy: PNode): SizeInt; static;
    class operator Initialize(var rt: TGLiteRootedTree); inline;
    class operator Finalize(var rt: TGLiteRootedTree);
    class operator Copy(constref aSrc: TGLiteRootedTree; var aDst: TGLiteRootedTree); inline;
    class operator AddRef(var rt: TGLiteRootedTree); inline;
  public
    class function CopySubTree(aNode: TTreeNode; out aTree: TGLiteRootedTree): SizeInt; static; inline;
    function  GetEnumerator: TTreeNode.TEnumerator;
  { makes the tree empty }
    procedure Clear;
    function  IsEmpty: Boolean; inline;
  { returns degree of the root or -1 if the tree is empty }
    function  Degree: SizeInt; inline;
  { returns height of the root or -1 if the tree is empty }
    function  Height: SizeInt; inline;
  { returns True if the node aNode belongs to the tree }
    function  OwnsNode(aNode: TTreeNode): Boolean; inline;
  { removes the node aNode with its subtree and returns the size of this subtree if aNode
    is not the root of another tree, otherwise returns 0 }
    function  RemoveNode(aNode: TTreeNode): SizeInt;
    property  Root: TTreeNode read GetRoot;
  { number of nodes in the tree }
    property  Count: SizeInt read GetCount;
  end;

  { TGLiteObjRootedTree }
  generic TGLiteObjRootedTree<T: class> = record
  private
  public
  type
    TTree           = specialize TGLiteRootedTree<T>;
    TTreeNode       = TTree.TTreeNode;
    PValue          = TTree.PValue;
    TArray          = TTree.TArray;
    TValueEvent     = TTree.TNodeEvent;
    TNestValueEvent = TTree.TNestNodeEvent;
  private
    FTree: TTree;
    FOwnsObjects: Boolean;
    function GetCount: SizeInt; inline;
    function GetRoot: TTreeNode; inline;
    function DoClear: SizeInt;
    class operator Initialize(var ort: TGLiteObjRootedTree);
    class operator Finalize(var ort: TGLiteObjRootedTree);
  public
    function  GetEnumerator: TTreeNode.TEnumerator;
    procedure Clear;
    function  IsEmpty: Boolean; inline;
    function  Degree: SizeInt; inline;
    function  Height: SizeInt; inline;
    function  OwnsNode(aNode: TTreeNode): Boolean; inline;
    function  RemoveNode(aNode: TTreeNode): SizeInt;
    property  Root: TTreeNode read GetRoot;
    property  Count: SizeInt read GetCount;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

implementation
{$B-}{$COPERATORS ON}{$POINTERMATH ON}

{ TGLiteRootedTree.TVisitNode }

constructor TGLiteRootedTree.TVisitNode.Create(aNode: PNode);
begin
  Node := aNode;
  Visited := False;
end;

{ TGLiteRootedTree.TNodePair }

constructor TGLiteRootedTree.TNodePair.Create(aNode, aCopy: PNode);
begin
  Node := aNode;
  NodeCopy := aCopy;
end;

{ TGLiteRootedTree.TLvlNode }

constructor TGLiteRootedTree.TLvlNode.Create(aNode: PNode; aLevel: SizeInt);
begin
  Node := aNode;
  Level := aLevel;
end;

{ TGLiteRootedTree.TTreeNode.TEnumNode }

constructor TGLiteRootedTree.TTreeNode.TEnumNode.Create(aNode: PNode);
begin
  Node := aNode;
  Visited := False;
end;

{ TGLiteRootedTree.TTreeNode.TEnumerator }

function TGLiteRootedTree.TTreeNode.TEnumerator.GetCurrent: TTreeNode;
begin
  Result.FNode := FCurrent;
end;

function TGLiteRootedTree.TTreeNode.TEnumerator.MoveNext: Boolean;
var
  Next: PNode;
begin
  Result := FQueue.TryDequeue(FCurrent);
  if Result then
    begin
      Next := FCurrent^.Child;
      while Next <> nil do
        begin
          FQueue.Enqueue(Next);
          Next := Next^.Sibling;
        end;
    end;
end;

{ TGLiteRootedTree.TTreeNode.TAncestorEnumerator }

function TGLiteRootedTree.TTreeNode.TAncestorEnumerator.GetCurrent: TTreeNode;
begin
  Result.FNode := FCurrent;
end;

function TGLiteRootedTree.TTreeNode.TAncestorEnumerator.MoveNext: Boolean;
begin
  if FNext <> nil then
    begin
      FCurrent := FNext;
      FNext := FNext^.Parent;
      exit(True);
    end;
  Result := False;
end;

{ TGLiteRootedTree.TTreeNode.TAncestors }

function TGLiteRootedTree.TTreeNode.TAncestors.GetEnumerator: TAncestorEnumerator;
begin
  Result.FCurrent := nil;
  Result.FNext := FNode^.Parent;
end;

function TGLiteRootedTree.TTreeNode.TAncestors.ToArray: TArray;
var
  I: SizeInt = 0;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  with GetEnumerator do
    while MoveNext do
      begin
        if I = System.Length(Result) then
          System.SetLength(Result, I * 2);
        Result[I] := Current.FNode^.Value;
        Inc(I);
      end;
  System.SetLength(Result, I);
end;

{ TGLiteRootedTree.TTreeNode.TChildEnumerator }

function TGLiteRootedTree.TTreeNode.TChildEnumerator.GetCurrent: TTreeNode;
begin
  Result.FNode := FCurrent;
end;

function TGLiteRootedTree.TTreeNode.TChildEnumerator.MoveNext: Boolean;
begin
  if FNext <> nil then
    begin
      FCurrent := FNext;
      FNext := FNext^.Sibling;
      exit(True);
    end;
  Result := False;
end;

{ TGLiteRootedTree.TTreeNode.TChildren }

function TGLiteRootedTree.TTreeNode.TChildren.GetEnumerator: TChildEnumerator;
begin
  Result.FCurrent := nil;
  Result.FNext := FNode^.Child;
end;

function TGLiteRootedTree.TTreeNode.TChildren.ToArray: TArray;
var
  I: SizeInt = 0;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  with GetEnumerator do
    while MoveNext do
      begin
        if I = System.Length(Result) then
          System.SetLength(Result, I * 2);
        Result[I] := Current.FNode^.Value;
        Inc(I);
      end;
  System.SetLength(Result, I);
end;

{ TGLiteRootedTree.TTreeNode.TPreordEnumerator }

function TGLiteRootedTree.TTreeNode.TPreordEnumerator.GetCurrent: TTreeNode;
begin
  Result.FNode := FCurrent;
end;

function TGLiteRootedTree.TTreeNode.TPreordEnumerator.MoveNext: Boolean;
var
  Next: PNode;
begin
  Result := FStack.TryPop(FCurrent);
  if Result then
    begin
      Next := FCurrent^.Child;
      while Next <> nil do
        begin
          FStack.Push(Next);
          Next := Next^.Sibling;
        end;
    end;
end;

{ TGLiteRootedTree.TTreeNode.TPreordTraversal }

function TGLiteRootedTree.TTreeNode.TPreordTraversal.GetEnumerator: TPreordEnumerator;
begin
  Result.FCurrent := nil;
  Result.FStack.Push(FNode);
end;

function TGLiteRootedTree.TTreeNode.TPreordTraversal.ToArray: TArray;
var
  I: SizeInt = 0;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  with GetEnumerator do
    while MoveNext do
      begin
        if I = System.Length(Result) then
          System.SetLength(Result, I * 2);
        Result[I] := Current.FNode^.Value;
        Inc(I);
      end;
  System.SetLength(Result, I);
end;

{ TGLiteRootedTree.TTreeNode.TPostordEnumerator }

function TGLiteRootedTree.TTreeNode.TPostordEnumerator.GetCurrent: TTreeNode;
begin
  Result.FNode := FCurrent;
end;

function TGLiteRootedTree.TTreeNode.TPostordEnumerator.MoveNext: Boolean;
var
  Next: PNode;
  pFlag: PVisitNode;
begin
  Result := FStack.NonEmpty;
  if Result then
    repeat
       pFlag := FStack.PeekItem;
       if not pFlag^.Visited then
         begin
           pFlag^.Visited := True;
           Next := pFlag^.Node^.Child;
           while Next <> nil do
             begin
               FStack.Push(TVisitNode.Create(Next));
               Next := Next^.Sibling;
             end;
         end
       else
         begin
           FCurrent := FStack.Pop.Node;
           break;
         end;
    until False;
end;

{ TGLiteRootedTree.TTreeNode.TPostordTraversal }

function TGLiteRootedTree.TTreeNode.TPostordTraversal.GetEnumerator: TPostordEnumerator;
begin
  Result.FCurrent := nil;
  Result.FStack.Push(TVisitNode.Create(FNode));
end;

function TGLiteRootedTree.TTreeNode.TPostordTraversal.ToArray: TArray;
var
  I: SizeInt = 0;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  with GetEnumerator do
    while MoveNext do
      begin
        if I = System.Length(Result) then
          System.SetLength(Result, I * 2);
        Result[I] := Current.FNode^.Value;
        Inc(I);
      end;
  System.SetLength(Result, I);
end;

{ TGLiteRootedTree.TTreeNode }

function TGLiteRootedTree.TTreeNode.GetValue: T;
begin
  Result := FNode^.Value;
end;

function TGLiteRootedTree.TTreeNode.GetMutValue: PValue;
begin
  Result := @FNode^.Value;
end;

procedure TGLiteRootedTree.TTreeNode.SetValue(const aValue: T);
begin
  FNode^.Value := aValue;
end;

function TGLiteRootedTree.TTreeNode.GetRoot: TTreeNode;
var
  Next: PNode;
begin
  Result.FNode := FNode;
  Next := FNode^.Parent;
  if Next <> nil then
    repeat
       Result.FNode := Next;
       Next := Next^.Parent;
    until Next = nil;
end;

function TGLiteRootedTree.TTreeNode.GetDepth(out aRoot: PNode): SizeInt;
var
  Next: PNode;
begin
  Result := 0;
  aRoot := FNode;
  Next := FNode^.Parent;
  while Next <> nil do
    begin
      aRoot := Next;
      Next := Next^.Parent;
      Inc(Result);
    end;
end;

class function TGLiteRootedTree.TTreeNode.AddNodeChild(aNode, aChild: PNode): PNode;
begin
  aChild^.Parent := aNode;
  aChild^.Sibling := aNode^.Child;
  aNode^.Child := aChild;
  Result := aChild;
end;

class function TGLiteRootedTree.TTreeNode.FindLastNodeChild(aNode: PNode; out aChild: PNode): Boolean;
begin
  aChild := aNode^.Child;
  Result := aChild <> nil;
  if Result then
    while aChild^.Sibling <> nil do
      aChild := aChild^.Sibling;
end;

class function TGLiteRootedTree.TTreeNode.AddNodeLastChild(aNode, aChild: PNode): PNode;
var
  LastChild: PNode;
begin
  if FindLastNodeChild(aNode, LastChild) then
    begin
      aChild^.Parent := aNode;
      LastChild^.Sibling := aChild;
      Result := aChild;
    end
  else
    Result := AddNodeChild(aNode, aChild);
end;

class procedure TGLiteRootedTree.TTreeNode.CutFromTree(aNode: PNode);
var
  Prev: PNode;
begin
  if aNode^.Parent^.Child = aNode then
    aNode^.Parent^.Child := aNode^.Sibling
  else
    begin
      Prev := aNode^.Parent^.Child;
      while Prev^.Sibling <> aNode do
        Prev := Prev^.Sibling;
      Prev^.Sibling := aNode^.Sibling;
    end;
  aNode^.Parent := nil;
  aNode^.Sibling := nil;
end;

class operator TGLiteRootedTree.TTreeNode.:=(aNode: PNode): TTreeNode;
begin
  Result.FNode := aNode;
end;

function TGLiteRootedTree.TTreeNode.GetChildEnumerator: TChildEnumerator;
begin
  Result.FCurrent := nil;
  Result.FNext := FNode^.Child;
end;

class operator TGLiteRootedTree.TTreeNode.=(L, R: TTreeNode): Boolean;
begin
  Result := L.FNode = R.FNode;
end;

function TGLiteRootedTree.TTreeNode.GetEnumerator: TEnumerator;
begin
  Result.FCurrent := nil;
  Result.FQueue.Enqueue(FNode);
end;

function TGLiteRootedTree.TTreeNode.Assigned: Boolean;
begin
  Result := FNode <> nil;
end;

procedure TGLiteRootedTree.TTreeNode.Clear;
begin
  FNode := nil;
end;

function TGLiteRootedTree.TTreeNode.IsRoot: Boolean;
begin
  Result := FNode^.Parent = nil;
end;

function TGLiteRootedTree.TTreeNode.IsLeaf: Boolean;
begin
  Result := FNode^.Child = nil;
end;

function TGLiteRootedTree.TTreeNode.Degree: SizeInt;
var
  Next: PNode;
begin
  Result := 0;
  Next := FNode^.Child;
  while Next <> nil do
    begin
      Inc(Result);
      Next := Next^.Sibling;
    end;
end;

function TGLiteRootedTree.TTreeNode.Level: SizeInt;
var
  Dummy: PNode;
begin
  Result := GetDepth(Dummy);
end;

function TGLiteRootedTree.TTreeNode.Height: SizeInt;
var
  Queue: TLvlQueue;
  Curr: TLvlNode;
  Next: PNode;
  h: SizeInt;
begin
  Queue.Enqueue(TLvlNode.Create(FNode, 0));
  Curr := Default(TLvlNode);
  Result := 0;
  while Queue.TryDequeue(Curr) do
    begin
      Next := Curr.Node^.Child;
      if Curr.Level > Result then
        Result := Curr.Level;
      if Next <> nil then
        begin
          h := Succ(Curr.Level);
          repeat
             Queue.Enqueue(TLvlNode.Create(Next, h));
             Next := Next^.Sibling;
          until Next = nil;
        end;
    end;
end;

function TGLiteRootedTree.TTreeNode.Width(out aLevel: SizeInt): SizeInt;
var
  Queue: TLvlQueue;
  Curr: TLvlNode;
  Next: PNode;
  Lvl: SizeInt;
begin
  aLevel := GetDepth(Next);
  Queue.Enqueue(TLvlNode.Create(Next, 0));
  Curr := Default(TLvlNode);
  Result := 0;
  while Queue.TryDequeue(Curr) do
    begin
      if Curr.Level > aLevel then
        exit;
      Next := Curr.Node^.Child;
      Result += Ord(Curr.Level = aLevel);
      if Next <> nil then
        begin
          Lvl := Succ(Curr.Level);
          repeat
             Queue.Enqueue(TLvlNode.Create(Next, Lvl));
             Next := Next^.Sibling;
          until Next = nil;
        end;
    end;
end;

function TGLiteRootedTree.TTreeNode.Size: SizeInt;
var
  Stack: TNodeStack;
  Curr: PNode = nil;
  Next: PNode;
begin
  Stack.Push(FNode);
  Result := 0;
  while Stack.TryPop(Curr) do
    begin
      Inc(Result);
      Next := Curr^.Child;
      while Next <> nil do
        begin
          Stack.Push(Next);
          Next := Next^.Sibling;
        end;
    end;
end;

function TGLiteRootedTree.TTreeNode.HasParent: Boolean;
begin
  Result := FNode^.Parent <> nil;
end;

function TGLiteRootedTree.TTreeNode.HasChildren: Boolean;
begin
  Result := FNode^.Child <> nil;
end;

function TGLiteRootedTree.TTreeNode.HasSibling: Boolean;
begin
  Result := FNode^.Sibling <> nil;
end;

function TGLiteRootedTree.TTreeNode.GetParent(out aParent: TTreeNode): Boolean;
begin
  aParent.FNode := FNode^.Parent;
  Result := aParent.FNode <> nil;
end;

function TGLiteRootedTree.TTreeNode.GetFirstChild(out aChild: TTreeNode): Boolean;
begin
  aChild.FNode := FNode^.Child;
  Result := aChild.FNode <> nil;
end;

function TGLiteRootedTree.TTreeNode.GetLastChild(out aChild: TTreeNode): Boolean;
begin
  Result := FindLastNodeChild(FNode, aChild.FNode);
end;

function TGLiteRootedTree.TTreeNode.GetSibling(out aSibling: TTreeNode): Boolean;
begin
  aSibling.FNode := FNode^.Sibling;
  Result := aSibling.FNode <> nil;
end;

function TGLiteRootedTree.TTreeNode.InSameTree(aNode: TTreeNode): Boolean;
begin
  Result := Root.FNode = aNode.Root.FNode;
end;

function TGLiteRootedTree.TTreeNode.DistanceFrom(aNode: TTreeNode): SizeInt;
var
  L, R: PNode;
  LDep, RDep: SizeInt;
begin
  if FNode = aNode.FNode then
    exit(0);
  LDep := GetDepth(L);
  RDep := aNode.GetDepth(R);
  if L <> R then
    exit(NULL_INDEX);
  L := FNode;
  R := aNode.FNode;
  Result := 0;
  if LDep < RDep then
    begin
      repeat
         R := R^.Parent;
         Dec(RDep);
         Inc(Result);
      until LDep = RDep;
      if R = L then
        exit;
    end
  else
    if RDep < LDep then
      begin
        repeat
           L := L^.Parent;
           Dec(LDep);
           Inc(Result);
        until LDep = RDep;
      end;
  while L <> R do
    begin
      L := L^.Parent;
      R := R^.Parent;
      Inc(Result, 2);
    end;
end;

function TGLiteRootedTree.TTreeNode.IsDescendantOf(aNode: TTreeNode): Boolean;
var
  Node: PNode;
begin
  if FNode = aNode.FNode then
    exit(False);
  Node := FNode;
  while Node <> nil do
    begin
      Node := Node^.Parent;
      if Node = aNode.FNode then
        exit(True);
    end;
  Result := False;
end;

function TGLiteRootedTree.TTreeNode.IsAncestorOf(aNode: TTreeNode): Boolean;
var
  Node: PNode;
begin
  if FNode = aNode.FNode then
    exit(False);
  Node := aNode.FNode;
  while Node <> nil do
    begin
      Node := Node^.Parent;
      if Node = FNode then
        exit(True);
    end;
  Result := False;
end;

function TGLiteRootedTree.TTreeNode.GetLca(aNode: TTreeNode; out aLca: TTreeNode): Boolean;
var
  L, R: PNode;
  LDep, RDep: SizeInt;
begin
  aLca.FNode := nil;
  if IsRoot or aNode.IsRoot then
    exit(False);
  if FNode = aNode.FNode then
    begin
      aLca.FNode := FNode^.Parent;
      exit(True);
    end;
  LDep := GetDepth(L);
  RDep := aNode.GetDepth(R);
  if L <> R then
    exit(False);
  L := FNode;
  R := aNode.FNode;
  while LDep < RDep do
    begin
      R := R^.Parent;
      Dec(RDep);
    end;
  while RDep < LDep do
    begin
      L := L^.Parent;
      Dec(LDep);
    end;
  while L <> R do
    begin
      L := L^.Parent;
      R := R^.Parent;
    end;
  if (L = FNode) or (L = aNode.FNode) then
    aLca.FNode := L^.Parent
  else
    aLca.FNode := L;
  Result := True;
end;

function TGLiteRootedTree.TTreeNode.AddChild: TTreeNode;
begin
  Result.FNode := AddNodeChild(FNode, TGLiteRootedTree.CreateNode);
end;

function TGLiteRootedTree.TTreeNode.AddChild(const aValue: T): TTreeNode;
begin
  Result.FNode := AddNodeChild(FNode, TGLiteRootedTree.NewNode(aValue));
end;

function TGLiteRootedTree.TTreeNode.AddChildTree(var aTree: TGLiteRootedTree): TTreeNode;
begin
  Result.FNode := AddNodeChild(FNode, aTree.FRoot);
  aTree.FRoot := nil;
end;

function TGLiteRootedTree.TTreeNode.AddLastChild: TTreeNode;
begin
  Result.FNode := AddNodeLastChild(FNode, TGLiteRootedTree.CreateNode);
end;

function TGLiteRootedTree.TTreeNode.AddLastChild(const aValue: T): TTreeNode;
begin
  Result.FNode := AddNodeLastChild(FNode, TGLiteRootedTree.NewNode(aValue));
end;

function TGLiteRootedTree.TTreeNode.AddLastChildTree(var aTree: TGLiteRootedTree): TTreeNode;
begin
  Result.FNode := AddNodeLastChild(FNode, aTree.FRoot);
  aTree.FRoot := nil;
end;

function TGLiteRootedTree.TTreeNode.Extract(out aTree: TGLiteRootedTree): Boolean;
begin
  if IsRoot then
    exit(False);
  CutFromTree(FNode);
  aTree.AssignRoot(FNode);
  Result := True;
end;

function TGLiteRootedTree.TTreeNode.Ancestors: TAncestors;
begin
  Result.FNode := FNode;
end;

function TGLiteRootedTree.TTreeNode.Children: TChildren;
begin
  Result.FNode := FNode;
end;

function TGLiteRootedTree.TTreeNode.PreorderTraversal: TPreordTraversal;
begin
  Result.FNode := FNode;
end;

function TGLiteRootedTree.TTreeNode.PostorderTraversal: TPostordTraversal;
begin
  Result.FNode := FNode;
end;

function TGLiteRootedTree.TTreeNode.BfsTraversal(aOnWhite, aOnGray, aOnBlack: TNodeEvent): SizeInt;
var
  Queue: TQueue;
  Curr: PNode = nil;
  Next: PNode;
begin
  if aOnWhite <> nil then
    aOnWhite(TTreeNode(FNode));
  Queue.Enqueue(FNode);
  Result := 0;
  while Queue.TryDequeue(Curr) do
    begin
      Inc(Result);
      if aOnGray <> nil then
        aOnGray(TTreeNode(Curr));
      Next := Curr^.Child;
      while Next <> nil do
        begin
          if aOnWhite <> nil then
            aOnWhite(TTreeNode(Next));
          Queue.Enqueue(Next);
          Next := Next^.Sibling;
        end;
      if aOnBlack <> nil then
        aOnBlack(TTreeNode(Curr));
    end;
end;

function TGLiteRootedTree.TTreeNode.BfsTraversal(aOnWhite, aOnGray, aOnBlack: TNestNodeEvent): SizeInt;
var
  Queue: TQueue;
  Curr: PNode = nil;
  Next: PNode;
begin
  if aOnWhite <> nil then
    aOnWhite(TTreeNode(FNode));
  Queue.Enqueue(FNode);
  Result := 0;
  while Queue.TryDequeue(Curr) do
    begin
      Inc(Result);
      if aOnGray <> nil then
        aOnGray(TTreeNode(Curr));
      Next := Curr^.Child;
      while Next <> nil do
        begin
          if aOnWhite <> nil then
            aOnWhite(TTreeNode(Next));
          Queue.Enqueue(Next);
          Next := Next^.Sibling;
        end;
      if aOnBlack <> nil then
        aOnBlack(TTreeNode(Curr));
    end;
end;

function TGLiteRootedTree.TTreeNode.DfsTraversalR2L(aOnWhite, aOnGray, aOnBlack: TNodeEvent): SizeInt;
var
  Stack: TVisitStack;
  Next: PNode;
  pFlag: PVisitNode = nil;
begin
  if aOnWhite <> nil then
    aOnWhite(TTreeNode(FNode));
  Stack.Push(TVisitNode.Create(FNode));
  Result := 0;
  while Stack.TryPeekItem(pFlag) do
    if not pFlag^.Visited then
      begin
        pFlag^.Visited := True;
        if aOnGray <> nil then
          aOnGray(TTreeNode(pFlag^.Node));
        Next := pFlag^.Node^.Child;
        while Next <> nil do
          begin
            if aOnWhite <> nil then
              aOnWhite(TTreeNode(Next));
            Stack.Push(TVisitNode.Create(Next));
            Next := Next^.Sibling;
          end;
      end
    else
      begin
        Next := Stack.Pop.Node;
        Inc(Result);
        if aOnBlack <> nil then
          aOnBlack(TTreeNode(Next));
      end;
end;

function TGLiteRootedTree.TTreeNode.DfsTraversalR2L(aOnWhite, aOnGray, aOnBlack: TNestNodeEvent): SizeInt;
var
  Stack: TVisitStack;
  Next: PNode;
  pFlag: PVisitNode = nil;
begin
  if aOnWhite <> nil then
    aOnWhite(TTreeNode(FNode));
  Stack.Push(TVisitNode.Create(FNode));
  Result := 0;
  while Stack.TryPeekItem(pFlag) do
    if not pFlag^.Visited then
      begin
        pFlag^.Visited := True;
        if aOnGray <> nil then
          aOnGray(TTreeNode(pFlag^.Node));
        Next := pFlag^.Node^.Child;
        while Next <> nil do
          begin
            if aOnWhite <> nil then
              aOnWhite(TTreeNode(Next));
            Stack.Push(TVisitNode.Create(Next));
            Next := Next^.Sibling;
          end;
      end
    else
      begin
        Next := Stack.Pop.Node;
        Inc(Result);
        if aOnBlack <> nil then
          aOnBlack(TTreeNode(Next));
      end;
end;

function TGLiteRootedTree.TTreeNode.DfsTraversalL2R(aOnWhite, aOnGray, aOnBlack: TNodeEvent): SizeInt;
var
  Stack: TEnumStack;
  Next: PNode;
  Curr: PEnumNode = nil;
begin
  if aOnWhite <> nil then
    aOnWhite(Self);
  Stack.Push(TEnumNode.Create(FNode));
  Result := 0;
  while Stack.TryPeekItem(Curr) do
    begin
      if not Curr^.Visited then
        begin
          Curr^.Visited := True;
          Curr^.Enum := TTreeNode(Curr^.Node).GetChildEnumerator;
          if aOnGray <> nil then
            aOnGray(TTreeNode(Curr^.Node));
        end;
      if Curr^.Enum.MoveNext then
        begin
          Next := Curr^.Enum.FCurrent;
          if aOnWhite <> nil then
            aOnWhite(TTreeNode(Next));
          Stack.Push(TEnumNode.Create(Next));
        end
      else
        begin
          Next := Stack.Pop.Node;
          Inc(Result);
          if aOnBlack <> nil then
            aOnBlack(TTreeNode(Next));
        end;
    end;
end;

function TGLiteRootedTree.TTreeNode.DfsTraversalL2R(aOnWhite, aOnGray, aOnBlack: TNestNodeEvent): SizeInt;
var
  Stack: TEnumStack;
  Next: PNode;
  Curr: PEnumNode = nil;
begin
  if aOnWhite <> nil then
    aOnWhite(Self);
  Stack.Push(TEnumNode.Create(FNode));
  Result := 0;
  while Stack.TryPeekItem(Curr) do
    begin
      if not Curr^.Visited then
        begin
          Curr^.Visited := True;
          Curr^.Enum := TTreeNode(Curr^.Node).GetChildEnumerator;
          if aOnGray <> nil then
            aOnGray(TTreeNode(Curr^.Node));
        end;
      if Curr^.Enum.MoveNext then
        begin
          Next := Curr^.Enum.FCurrent;
          if aOnWhite <> nil then
            aOnWhite(TTreeNode(Next));
          Stack.Push(TEnumNode.Create(Next));
        end
      else
        begin
          Next := Stack.Pop.Node;
          Inc(Result);
          if aOnBlack <> nil then
            aOnBlack(TTreeNode(Next));
        end;
    end;
end;

{ TGLiteRootedTree }

procedure TGLiteRootedTree.AssignRoot(aNode: PNode);
begin
  FRoot := aNode;
  FOwnsRoot := True;
end;

function TGLiteRootedTree.GetRoot: TTreeNode;
begin
  if FRoot = nil then
    AssignRoot(CreateNode);
  Result.FNode := FRoot;
end;

function TGLiteRootedTree.GetCount: SizeInt;
begin
  if FRoot = nil then
    exit(0);
  Result := Root.Size;
end;

function TGLiteRootedTree.RemoveNode(aNode: TTreeNode; aOnRemove: TNestNodeEvent): SizeInt;
begin
  if aNode.IsRoot then
    exit(0);
  TTreeNode.CutFromTree(aNode.FNode);
  if aOnRemove <> nil then
    Result := DoRemoveNode(aNode.FNode, aOnRemove)
  else
    Result := DoRemoveNode(aNode.FNode);
end;

function TGLiteRootedTree.DoClear: SizeInt;
begin
  Result := 0;
  if FRoot <> nil then
    begin
      if FOwnsRoot then
        Result += DoRemoveNode(FRoot);
      FRoot := nil;
      FOwnsRoot := False;
    end;
end;

class function TGLiteRootedTree.DoRemoveNode(aNode: PNode): SizeInt;
var
  Stack: TNodeStack;
  Curr: PNode = nil;
  Next: PNode;
begin
  Stack.Push(aNode);
  Result := 0;
  while Stack.TryPop(Curr) do
    begin
      Inc(Result);
      Next := Curr^.Child;
      while Next <> nil do
        begin
          Stack.Push(Next);
          Next := Next^.Sibling;
        end;
      FreeNode(Curr);
    end;
end;

class function TGLiteRootedTree.DoRemoveNode(aNode: PNode; aBeforeRemove: TNestNodeEvent): SizeInt;
var
  Stack: TNodeStack;
  Curr: PNode = nil;
  Next: PNode;
begin
  Stack.Push(aNode);
  Result := 0;
  while Stack.TryPop(Curr) do
    begin
      Inc(Result);
      Next := Curr^.Child;
      while Next <> nil do
        begin
          Stack.Push(Next);
          Next := Next^.Sibling;
        end;
      aBeforeRemove(TTreeNode(Curr));
      FreeNode(Curr);
    end;
end;

class function TGLiteRootedTree.NewNode(const aValue: T): PNode;
begin
  Result := CreateNode;
  Result^.Value := aValue;
end;

class function TGLiteRootedTree.CreateNode: PNode;
begin
  Result := GetMem(SizeOf(TNode));
  FillChar(Result^, SizeOf(TNode), 0);
end;

class procedure TGLiteRootedTree.FreeNode(aNode: PNode);
begin
  if aNode <> nil then
    begin
      aNode^.Value := Default(T);
      FreeMem(aNode);
    end;
end;

class function TGLiteRootedTree.SubTreeCopy(aNode: PNode; out aNodeCopy: PNode): SizeInt;
var
  Queue: TPairQueue;
  Stack: TNodeStack;
  CurrPair: TNodePair;
  Next, NodeCopy, NextCopy, Sibling: PNode;
begin
  Result := 0;
  aNodeCopy := nil;
  if aNode = nil then
    exit;
  CurrPair := Default(TNodePair);
  aNodeCopy := NewNode(aNode^.Value);
  Queue.Enqueue(TNodePair.Create(aNode, aNodeCopy));
  while Queue.TryDequeue(CurrPair) do
    begin
      Inc(Result);
      Next := CurrPair.Node^.Child;
      NodeCopy := CurrPair.NodeCopy;
      while Next <> nil do
        begin
          NextCopy := NewNode(Next^.Value);
          NextCopy^.Parent := NodeCopy;
          Queue.Enqueue(TNodePair.Create(Next, NextCopy));
          Stack.Push(NextCopy);
          Next := Next^.Sibling;
        end;
      Sibling := nil;
      while Stack.TryPop(NextCopy) do
        begin
          NextCopy^.Sibling := Sibling;
          Sibling := NextCopy;
        end;
      NodeCopy^.Child := Sibling;
    end;
end;

class operator TGLiteRootedTree.Initialize(var rt: TGLiteRootedTree);
begin
  rt.FRoot := nil;
  rt.FOwnsRoot := False;
end;

class operator TGLiteRootedTree.Finalize(var rt: TGLiteRootedTree);
begin
  rt.Clear;
end;

class operator TGLiteRootedTree.Copy(constref aSrc: TGLiteRootedTree; var aDst: TGLiteRootedTree);
begin
  aDst.Clear;
  aSrc.SubTreeCopy(aSrc.FRoot, aDst.FRoot);
  aDst.FOwnsRoot := True;
end;

class operator TGLiteRootedTree.AddRef(var rt: TGLiteRootedTree);
begin
  if rt.FRoot <> nil then
    rt.FOwnsRoot := False;
end;

class function TGLiteRootedTree.CopySubTree(aNode: TTreeNode; out aTree: TGLiteRootedTree): SizeInt;
begin
  Result := SubTreeCopy(aNode.FNode, aTree.FRoot);
end;

function TGLiteRootedTree.GetEnumerator: TTreeNode.TEnumerator;
begin
  Result.FCurrent := nil;
  if FRoot <> nil then
    Result.FQueue.Enqueue(FRoot);
end;

procedure TGLiteRootedTree.Clear;
begin
  DoClear;
end;

function TGLiteRootedTree.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

function TGLiteRootedTree.Degree: SizeInt;
begin
  if FRoot <> nil then
    Result := TTreeNode(FRoot).Degree
  else
    Result := NULL_INDEX;
end;

function TGLiteRootedTree.Height: SizeInt;
begin
  if FRoot <> nil then
    Result := TTreeNode(FRoot).Height
  else
    Result := NULL_INDEX;
end;

function TGLiteRootedTree.OwnsNode(aNode: TTreeNode): Boolean;
begin
  Result := aNode.Root = FRoot;
end;

function TGLiteRootedTree.RemoveNode(aNode: TTreeNode): SizeInt;
begin
  if FRoot = nil then
    exit(0);
  if aNode.FNode = FRoot then
    exit(DoClear);
  if aNode.IsRoot then
    exit(0);
  TTreeNode.CutFromTree(aNode.FNode);
  Result := DoRemoveNode(aNode.FNode);
end;

{ TGLiteObjRootedTree }

function TGLiteObjRootedTree.GetCount: SizeInt;
begin
  Result := FTree.Count;
end;

function TGLiteObjRootedTree.GetRoot: TTreeNode;
begin
  Result := FTree.Root;
end;

function TGLiteObjRootedTree.DoClear: SizeInt;
  procedure FreeNodeObj(aNode: TTreeNode);
  begin
    aNode.FNode^.Value.Free;
  end;
begin
  Result := 0;
  if FTree.FRoot <> nil then
    begin
      if OwnsObjects then
        Result := FTree.DoRemoveNode(FTree.FRoot, @FreeNodeObj)
      else
        Result := FTree.DoRemoveNode(FTree.FRoot);
      FTree.FRoot := nil;
    end;
end;

class operator TGLiteObjRootedTree.Initialize(var ort: TGLiteObjRootedTree);
begin
  ort.OwnsObjects := True;
end;

class operator TGLiteObjRootedTree.Finalize(var ort: TGLiteObjRootedTree);
begin
  ort.Clear;
end;

function TGLiteObjRootedTree.GetEnumerator: TTreeNode.TEnumerator;
begin
  Result := FTree.GetEnumerator;
end;

procedure TGLiteObjRootedTree.Clear;
begin
  DoClear;
end;

function TGLiteObjRootedTree.IsEmpty: Boolean;
begin
  Result := FTree.FRoot = nil;
end;

function TGLiteObjRootedTree.Degree: SizeInt;
begin
  Result := FTree.Degree;
end;

function TGLiteObjRootedTree.Height: SizeInt;
begin
  Result := FTree.Height;
end;

function TGLiteObjRootedTree.OwnsNode(aNode: TTreeNode): Boolean;
begin
  Result := FTree.OwnsNode(aNode);
end;

function TGLiteObjRootedTree.RemoveNode(aNode: TTreeNode): SizeInt;
  procedure FreeNodeObj(aNode: TTreeNode);
  begin
    aNode.FNode^.Value.Free;
  end;
begin
  if FTree.FRoot = nil then
    exit(0);
  if aNode.FNode = FTree.FRoot then
    exit(DoClear);
  if aNode.IsRoot then
    exit(0);
  if OwnsObjects then
    Result := FTree.RemoveNode(aNode, @FreeNodeObj)
  else
    Result := FTree.RemoveNode(aNode);
end;

end.  
