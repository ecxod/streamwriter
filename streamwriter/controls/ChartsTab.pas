{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010-2012 Alexander Nottelmann

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 3
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
    ------------------------------------------------------------------------
}

{ This unit is for showing radio-charts in the main-window }
unit ChartsTab;

interface

uses
  Windows, SysUtils, Classes, Controls, StdCtrls, ExtCtrls, ComCtrls, Buttons,
  MControls, LanguageObjects, Tabs, Functions, AppData, Logging, VirtualTrees,
  HomeCommunication, DataManager, ImgList, Graphics, Math, Generics.Collections,
  Menus, ChartsTabAdjustTitleName, Forms, TypeDefs, MessageBus, AppMessages;

type
  TNodeTypes = (ntChart, ntStream, ntAll);

  TChartNodeData = record
    Chart: TChartEntry;
    Stream: TChartStream;
    IsOnWishlist: Boolean;
  end;
  PChartNodeData = ^TChartNodeData;

  TChartDataArray = array of PChartNodeData;

  TChartsPopup = class(TPopupMenu)
  private
    FItemAddToWishlist: TMenuItem;
    FItemEditAndAddToWishlist: TMenuItem;
    FItemStartStreaming: TMenuItem;
    FItemPlayStream: TMenuItem;
    FItemPlayStreamExternal: TMenuItem;
    FItemAddStream: TMenuItem;
  public
    constructor Create(AOwner: TComponent); override;

    procedure EnableItems(SelectedCount: Integer; AllOnList: Boolean);

    property ItemAddToWishlist: TMenuItem read FItemAddToWishlist;
    property ItemEditAndAddToWishlist: TMenuItem read FItemEditAndAddToWishlist;
    property ItemStartStreaming: TMenuItem read FItemStartStreaming;
    property ItemPlayStream: TMenuItem read FItemPlayStream;
    property ItemPlayStreamExternal: TMenuItem read FItemPlayStreamExternal;
    property ItemAddStream: TMenuItem read FItemAddStream;
  end;

  TCategoryCombo = class(TComboBox)
  private
  public
    procedure LoadCategories(Categories: TList<TChartCategory>);
    procedure PostTranslate;
  end;

  TSearchPanel = class(TPanel)
  private
    FLabel: TLabel;
    FSearch: TEdit;
    FCategories: TCategoryCombo;
    FToolbar: TToolBar;

    FButtonReload: TToolButton;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); reintroduce;

    procedure Setup(Images: TImageList);
  end;

  TChartArray = array of TChartEntry;
  TChartStates = (csNormal, csLoading, csError);

  TChartsTree = class(TVirtualStringTree)
  private
    FTimer: TTimer;
    FDots: string;
    FTextLeft: Integer;

    FPopupMenu: TChartsPopup;

    FColImages: TVirtualTreeColumn;
    FColTitle: TVirtualTreeColumn;
    FColChance: TVirtualTreeColumn;

    FState: TChartStates;

    FLists: TDataLists;

    procedure PopupMenuPopup(Sender: TObject);
    procedure PopupMenuClick(Sender: TObject);

    procedure OnSaveListNotify(Sender: TObject; const Item: TTitleInfo; Action: TCollectionNotification);

    procedure TimerOnTimer(Sender: TObject);

    procedure FSetState(Value: TChartStates);

    procedure ExecDefaultAction;
  protected
    procedure DoGetText(Node: PVirtualNode; Column: TColumnIndex;
      TextType: TVSTTextType; var Text: string); override;
    function DoGetImageIndex(Node: PVirtualNode; Kind: TVTImageKind;
      Column: TColumnIndex; var Ghosted: Boolean;
      var Index: Integer): TCustomImageList; override;
    function DoCompare(Node1: PVirtualNode; Node2: PVirtualNode;
      Column: TColumnIndex): Integer; override;
    procedure DoHeaderClick(HitInfo: TVTHeaderHitInfo); override;
    procedure KeyPress(var Key: Char); override;
    procedure Paint; override;
    procedure DblClick; override;
    function DoIncrementalSearch(Node: PVirtualNode;
      const Text: string): Integer; override;
    procedure Resize; override;
    procedure DoAfterCellPaint(Canvas: TCanvas; Node: PVirtualNode;
      Column: TColumnIndex; CellRect: TRect); override;
  public
    constructor Create(AOwner: TComponent; Lists: TDataLists); reintroduce;
    destructor Destroy; override;

    function GetNodes(NodeTypes: TNodeTypes; SelectedOnly: Boolean): TNodeArray;
    function NodesToData(Nodes: TNodeArray): TChartDataArray;

    property State: TChartStates read FState write FSetState;
  end;

  TAddToWishlistEvent = procedure(Sender: TObject; List: TStringList) of object;
  TAddStreamsEvent = procedure(Sender: TObject; Info: TStartStreamingInfoArray; Action: TStreamOpenActions) of object;
  TGetIsStreamOnListEvent = function(Sender: TObject; Stream: TStreamBrowserEntry): Boolean of object;

  TChartsTab = class(TMainTabSheet)
  private
    FLists: TDataLists;
    FSearchPanel: TSearchPanel;
    FChartsTree: TChartsTree;
    FResultLabel: TLabel;

    FOnAddToWishlist: TAddToWishlistEvent;
    FOnAddStreams: TAddStreamsEvent;
    FOnGetIsStreamOnListEvent: TGetIsStreamOnListEvent;

    procedure ShowCharts;

    procedure SearchChange(Sender: TObject);

    procedure HomeCommChartsReceived(Sender: TObject; CategoryList: TList<TChartCategory>;
      ChartList: TList<TChartEntry>);
    procedure CategoriesChange(Sender: TObject);
    procedure ButtonReloadClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; Lists: TDataLists); reintroduce;
    destructor Destroy; override;

    procedure Setup(Images: TImageList);
    procedure PostTranslate;
    procedure SetState(State: TChartStates);

    procedure HomeCommStateChanged(Sender: TObject);

    property OnAddToWishlist: TAddToWishlistEvent read FOnAddToWishlist write FOnAddToWishlist;
    property OnAddStreams: TAddStreamsEvent read FOnAddStreams write FOnAddStreams;
    property OnGetIsStreamOnListEvent: TGetIsStreamOnListEvent read FOnGetIsStreamOnListEvent write FOnGetIsStreamOnListEvent;
  end;

const
  TEXT_LOADING = 'Loading charts';
  TEXT_ERROR = 'You need to be connected to the server.';
  TEXT_EVERYSONG = 'Every song';
  TEXT_RESULTS = '%d songs found';

implementation

{ TChartsTab }

procedure TChartsTab.ButtonReloadClick(Sender: TObject);
begin
  MsgBus.SendMessage(TRefreshServerData.Create);
end;

procedure TChartsTab.CategoriesChange(Sender: TObject);
begin
  ShowCharts;
end;

constructor TChartsTab.Create(AOwner: TComponent; Lists: TDataLists);
begin
  inherited Create(AOwner);

  FLists := Lists;

  FSearchPanel := TSearchPanel.Create(Self);
  FSearchPanel.Parent := Self;
  FSearchPanel.Align := alTop;

  FChartsTree := TChartsTree.Create(Self, FLists);
  FChartsTree.Parent := Self;
  FChartsTree.Align := alClient;

  FResultLabel := TLabel.Create(Self);
  FResultLabel.Parent := Self;
  FResultLabel.Align := alBottom;

  HomeComm.OnChartsReceived := HomeCommChartsReceived;

  ImageIndex := 68;
  ShowCloseButton := False;

  FSearchPanel.FSearch.OnChange := SearchChange;
  FSearchPanel.FCategories.OnChange := CategoriesChange;
end;

destructor TChartsTab.Destroy;
begin

  inherited;
end;

{
procedure TChartsTab.GetCharts;
begin
  if HomeComm.GetCharts then
    SetState(csLoading)
  else
    SetState(csError); // `WIRD DAS NOCH AUSGEWERTET MIT NEUEM ABLAUF?=??
end;
}

procedure TChartsTab.HomeCommChartsReceived(Sender: TObject; CategoryList: TList<TChartCategory>;
  ChartList: TList<TChartEntry>);
var
  i, j, n: Integer;
  Chart: TChartEntry;
begin
  FChartsTree.Clear;

  for i := 0 to FLists.ChartCategoryList.Count - 1 do
    FLists.ChartCategoryList[i].Free;
  FLists.ChartCategoryList.Clear;

  for i := 0 to CategoryList.Count - 1 do
    FLists.ChartCategoryList.Add(CategoryList[i].Copy);

  for i := 0 to FLists.ChartList.Count - 1 do
    FLists.ChartList[i].Free;
  FLists.ChartList.Clear;

  FLists.BrowserList.CreateDict;

  for i := 0 to ChartList.Count - 1 do
  begin
    Chart := ChartList[i].Copy;

    Chart.LoadStreams(FLists.BrowserList);

    FLists.ChartList.Add(Chart);
  end;

  FLists.BrowserList.ClearDict;

  SetState(csNormal);

  FSearchPanel.FCategories.LoadCategories(FLists.ChartCategoryList);

  ShowCharts;
end;

procedure TChartsTab.HomeCommStateChanged(Sender: TObject);
begin
  FSearchPanel.FButtonReload.Enabled := HomeComm.Connected;

  if (not HomeComm.Connected) and (FChartsTree.FState = csLoading) then
    SetState(csError);
end;

procedure TChartsTab.PostTranslate;
begin
  FChartsTree.FColImages.Text := _('State');
  FChartsTree.FColTitle.Text := _('Name');
  FChartsTree.FColChance.Text := _('Chance');

  FSearchPanel.FLabel.Caption := _('Search:');
  FSearchPanel.FCategories.PostTranslate;

  FResultLabel.Caption := Format(_(TEXT_RESULTS), [FChartsTree.RootNodeCount]);
end;

procedure TChartsTab.SearchChange(Sender: TObject);
begin
  ShowCharts;
end;

procedure TChartsTab.SetState(State: TChartStates);
begin
  if FChartsTree.FState <> State then
  begin
    FResultLabel.Enabled := State = csNormal;

    FChartsTree.BeginUpdate;
    FChartsTree.Clear;
    FChartsTree.EndUpdate;

    FChartsTree.State := State;
    FChartsTree.Invalidate;

    FSearchPanel.FSearch.Enabled := State = csNormal;
    FSearchPanel.FCategories.Enabled := State = csNormal;
    FSearchPanel.FToolbar.Enabled := State = csNormal;

    FSearchPanel.FButtonReload.Enabled := State = csNormal;
  end;
end;

procedure TChartsTab.Setup(Images: TImageList);
begin
  FSearchPanel.Setup(Images);

  FChartsTree.Images := Images;

  FChartsTree.PopupMenu.Images := Images;

  FSearchPanel.FButtonReload.OnClick := ButtonReloadClick;

  Caption := _('Charts');

  if ((FLists.ChartCategoryList.Count = 0) or (FLists.ChartList.Count = 0)) and (not HomeComm.Connected) then
  begin
    SetState(csError);
  end;

  if (FChartsTree.FState = csNormal) and (FLists.ChartList.Count > 0) and (FLists.CategoryList.Count > 0) then
  begin
    FSearchPanel.FCategories.LoadCategories(FLists.ChartCategoryList);
    FSearchPanel.FCategories.ItemIndex := 0;
    ShowCharts;
  end;
end;

procedure TChartsTab.ShowCharts;
var
  i, n: Integer;
  Node, NodeStream: PVirtualNode;
  NodeData, NodeDataStream: PChartNodeData;
  CatData: TChartCategory;

  P: string;
  Hash: Cardinal;
  Chars: Integer;

  CatMatch: Boolean;
  SearchMatch: Boolean;
begin
  if FSearchPanel.FCategories.ItemIndex = -1 then
    Exit;

  P := BuildPattern(FSearchPanel.FSearch.Text, Hash, Chars, False);

  try
    FChartsTree.BeginUpdate;
    FChartsTree.Clear;

    CatData := TChartCategory(FSearchPanel.FCategories.Items.Objects[FSearchPanel.FCategories.ItemIndex]);

    for i := 0 to FLists.ChartList.Count - 1 do
    begin
      CatMatch := False;

      if CatData = nil then
      begin
        CatMatch := True
      end else
      begin
        for n := 0 to High(FLists.ChartList[i].Categories) do
          if FLists.ChartList[i].Categories[n] = CatData.ID then
          begin
            CatMatch := True;
            Break;
          end;
      end;

      SearchMatch := Like(FLists.ChartList[i].Name, P);

      if CatMatch and SearchMatch then
      begin
        Node := FChartsTree.AddChild(nil);
        NodeData := FChartsTree.GetNodeData(Node);
        NodeData.Chart := FLists.ChartList[i];

        for n := 0 to NodeData.Chart.Streams.Count - 1 do
        begin
          NodeStream := FChartsTree.AddChild(Node);
          NodeDataStream := FChartsTree.GetNodeData(NodeStream);
          NodeDataStream.Stream := NodeData.Chart.Streams[n];
        end;

        for n := 0 to FLists.SaveList.Count - 1 do
          if LowerCase(FLists.SaveList[n].Title) = LowerCase(NodeData.Chart.Name) then
          begin
            NodeData.IsOnWishlist := True;
            Break;
          end;
      end;
    end;

    FChartsTree.SortTree(FChartsTree.Header.SortColumn, FChartsTree.Header.SortDirection);
  finally
    FChartsTree.EndUpdate;
  end;

  FResultLabel.Caption := Format(_(TEXT_RESULTS), [FChartsTree.RootNodeCount]);
end;

{ TChartsTree }

constructor TChartsTree.Create(AOwner: TComponent; Lists: TDataLists);
begin
  inherited Create(AOwner);

  FLists := Lists;

  FLists.SaveList.OnChange.Add(OnSaveListNotify);

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 1000;
  FTimer.Enabled := False;
  FTimer.OnTimer := TimerOnTimer;

  NodeDataSize := SizeOf(TChartNodeData);

  IncrementalSearch := isVisibleOnly;

  Header.Options := [hoColumnResize, hoShowSortGlyphs, hoVisible];
  TreeOptions.SelectionOptions := [toMultiSelect, toRightClickSelect, toFullRowSelect];
  TreeOptions.AutoOptions := [toAutoScrollOnExpand];
  TreeOptions.PaintOptions := [toThemeAware, toHideFocusRect, toShowRoot, toShowButtons];
  Header.Options := Header.Options - [hoAutoResize];
  Header.Options := Header.Options - [hoDrag];

  Header.AutoSizeIndex := 0;

  FColTitle := Header.Columns.Add;
  FColTitle.Text := _('Name');

  FColImages := Header.Columns.Add;
  FColImages.Text := _('State');
  FColImages.Width := 50;
  FColImages.Options := FColImages.Options - [coResizable];

  FColChance := Header.Columns.Add;
  FColChance.Text := _('Played last day/last week');
  FColChance.Width := 200;
  FColChance.Alignment := taRightJustify;

  Header.Options := Header.Options + [hoAutoResize];

  FPopupMenu := TChartsPopup.Create(Self);
  FPopupMenu.OnPopup := PopupMenuPopup;
  FPopupMenu.ItemAddToWishlist.OnClick := PopupMenuClick;
  FPopupMenu.ItemEditAndAddToWishlist.OnClick := PopupMenuClick;
  FPopupMenu.ItemStartStreaming.OnClick := PopupMenuClick;
  FPopupMenu.ItemPlayStream.OnClick := PopupMenuClick;
  FPopupMenu.ItemPlayStreamExternal.OnClick := PopupMenuClick;
  FPopupMenu.ItemAddStream.OnClick := PopupMenuClick;

  PopupMenu := FPopupMenu;

  Header.SortColumn := 2;
  Header.SortDirection := sdDescending;
end;

procedure TChartsTree.DblClick;
begin
  inherited;

  if (SelectedCount = 1) and (FocusedNode <> nil) and (GetNodeLevel(GetNodes(ntAll, True)[0]) = 1) then
    ExecDefaultAction;
end;

destructor TChartsTree.Destroy;
begin

  inherited;
end;

procedure TChartsTree.DoAfterCellPaint(Canvas: TCanvas; Node: PVirtualNode;
  Column: TColumnIndex; CellRect: TRect);
var
  C: Extended;
  Chance: Integer;
  R: TRect;
  DrawWidth, MaxWidth, TextWidth: Integer;
  Text: string;
  NodeData: PChartNodeData;
begin
  inherited;

  NodeData := GetNodeData(Node);
  if (Column = 2) and (NodeData.Chart <> nil) then
  begin
    C := (NodeData.Chart.PlayedLastWeek / 7) / 12;
    if C > 1 then
      C := 1;
    Chance := Trunc(C * 100);

    Canvas.Brush.Color := HTML2Color('#005fb0');
    if Selected[Node] and Focused then
      Canvas.Brush.Color := HTML2Color('#d2d2d2');

    TextWidth := Canvas.TextWidth('100 / 1000');
    MaxWidth := CellRect.Right - CellRect.Left - 8 - TextWidth;
    DrawWidth := Trunc((Chance / 100) * MaxWidth) - 2;

    if DrawWidth < 1 then
      Exit;

    R.Left := CellRect.Left + 2;
    R.Top := CellRect.Top + 2;
    R.Right := R.Left + DrawWidth;
    R.Bottom := CellRect.Bottom - 2;

    Canvas.FillRect(R);
  end;
end;

function TChartsTree.DoCompare(Node1, Node2: PVirtualNode;
  Column: TColumnIndex): Integer;
var
  C1, C2: Integer;
  Data1, Data2: PChartNodeData;
begin
  Result := 0;

  Data1 := GetNodeData(Node1);
  Data2 := GetNodeData(Node2);

  if (Data1.Chart = nil) or (Data2.Chart = nil) then
    Exit;

  case Column of
    0:
      Result := CompareText(Data1.Chart.Name, Data2.Chart.Name);
    1:
      begin
        C1 := 0;
        C2 := 0;
        if Data1.IsOnWishlist then
          C1 := C1 + 1;
        if Data2.IsOnWishlist then
          C2 := C2 + 1;

        Result := CmpInt(C1, C2);
        if Result = 0 then
        begin
          Result := CompareText(Data1.Chart.Name, Data2.Chart.Name);
          if Header.SortDirection = sdDescending then
            Result := Result * -1;
        end;
      end;
    2:
      begin
        Result := CmpInt(Data1.Chart.PlayedLastWeek, Data2.Chart.PlayedLastWeek);
        if Result = 0 then
        begin
          Result := CompareText(Data1.Chart.Name, Data2.Chart.Name);
          if Header.SortDirection = sdDescending then
            Result := Result * -1;
        end;
      end;
  end;
end;

function TChartsTree.DoGetImageIndex(Node: PVirtualNode;
  Kind: TVTImageKind; Column: TColumnIndex; var Ghosted: Boolean;
  var Index: Integer): TCustomImageList;
var
  NodeData: PChartNodeData;
  P: TControl;
begin
  Result := inherited;

  P := Parent;
  while not (P.ClassType = TChartsTab) do
    P := P.Parent;

  NodeData := GetNodeData(Node);
  if (Kind = ikNormal) or (Kind = ikSelected) then
    case Column of
      0:
        if NodeData.Chart <> nil then
          Index := 20
        else
          Index := 16;
      1:
        if NodeData.Chart <> nil then
        begin
          if NodeData.IsOnWishlist then
            Index := 31;
        end else
        begin
          if TChartsTab(P).FOnGetIsStreamOnListEvent(Self, NodeData.Stream.Stream) then
            Index := 80;
        end;
    end;
end;

procedure TChartsTree.DoGetText(Node: PVirtualNode; Column: TColumnIndex;
  TextType: TVSTTextType; var Text: string);
var
  NodeData: PChartNodeData;
begin
  inherited;

  Text := '';

  NodeData := GetNodeData(Node);
  case Column of
    0:
      if NodeData.Chart <> nil then
        Text := NodeData.Chart.Name
      else
        Text := NodeData.Stream.Stream.Name;
    2:
      if NodeData.Chart <> nil then
        Text := Format('%d / %d', [NodeData.Chart.PlayedLastDay, NodeData.Chart.PlayedLastWeek])
      else
        Text := Format('%d / %d', [NodeData.Stream.PlayedLastDay, NodeData.Stream.PlayedLastWeek]);
  end;
end;

 procedure TChartsTree.DoHeaderClick(HitInfo: TVTHeaderHitInfo);
begin
  inherited;
  if HitInfo.Button = mbLeft then
  begin
    if Header.SortColumn <> HitInfo.Column then
    begin
      Header.SortColumn := HitInfo.Column;
      case HitInfo.Column of
        1: Header.SortDirection := sdDescending;
        0: Header.SortDirection := sdAscending;
        2: Header.SortDirection := sdDescending;
      end;
    end else
    begin
      if Header.SortDirection = sdAscending then
        Header.SortDirection := sdDescending
      else
        Header.SortDirection := sdAscending;
    end;
    SortTree(Header.SortColumn, Header.SortDirection);
  end;
end;

function TChartsTree.DoIncrementalSearch(Node: PVirtualNode;
  const Text: string): Integer;
var
  NodeData: PChartNodeData;
begin
  NodeData := GetNodeData(Node);
  Result := StrLIComp(PChar(Text), PChar(NodeData.Chart.Name), Min(Length(Text), Length(NodeData.Chart.Name)));
end;

procedure TChartsTree.ExecDefaultAction;
var
  i: Integer;
  P: TControl;
  Nodes: TNodeArray;
  NodesData: TChartDataArray;
  Titles: TStringList;
  Info: TStartStreamingInfoArray;
begin
  P := Parent;
  while not (P.ClassType = TChartsTab) do
    P := P.Parent;

  Nodes := GetNodes(ntAll, True);
  NodesData := NodesToData(Nodes);

  Titles := TStringList.Create;
  SetLength(Info, 0);
  try
    for i := 0 to Length(NodesData) - 1 do
    begin
      if NodesData[i].Chart <> nil then
        Titles.Add(NodesData[i].Chart.Name)
      else
      begin
        SetLength(Info, Length(Info) + 1);
        Info[High(Info)] := TStartStreamingInfo.Create(NodesData[i].Stream.ID, NodesData[i].Stream.Stream.Bitrate,
          NodesData[i].Stream.Stream.Name, NodesData[i].Stream.Stream.URL, NodesData[i].Stream.Stream.RegEx,
          NodesData[i].Stream.Stream.IgnoreTitles);
      end;
    end;

    // TODO: was, wenns nicht klappt, wegen kein speicher frei oder so???
    case AppGlobals.DefaultActionBrowser of
      oaStart:
        TChartsTab(P).FOnAddStreams(Self, Info, oaStart);
      oaPlay:
        TChartsTab(P).FOnAddStreams(Self, Info, oaPlay);
      oaPlayExternal:
        TChartsTab(P).FOnAddStreams(Self, Info, oaPlayExternal);
      oaAdd:
        TChartsTab(P).FOnAddStreams(Self, Info, oaAdd)
    end;

    if Titles.Count > 0 then
      TChartsTab(P).FOnAddToWishlist(Self, Titles);

    for i := 0 to Length(Nodes) - 1 do
      InvalidateNode(Nodes[i]);
  finally
    Titles.Free;
  end;
end;

procedure TChartsTree.FSetState(Value: TChartStates);
begin
  FDots := '';

  FTimer.Enabled := False;

  case Value of
    csNormal:
      Enabled := True;
    csLoading:
      begin
        Enabled := False;
        FTextLeft := ClientWidth div 2 - Canvas.TextWidth(_(TEXT_LOADING) + '..') div 2;
        FTimer.Enabled := True;
        Invalidate;
      end;
    csError:
      begin
        Enabled := False;
        FTextLeft := ClientWidth div 2 - Canvas.TextWidth(_(TEXT_ERROR)) div 2;
        Invalidate;
      end;
  end;

  FState := Value;
end;

function TChartsTree.GetNodes(NodeTypes: TNodeTypes;
  SelectedOnly: Boolean): TNodeArray;
var
  Node: PVirtualNode;
  NodeData: PChartNodeData;
begin
  SetLength(Result, 0);
  Node := GetFirst;
  while Node <> nil do
  begin
    NodeData := GetNodeData(Node);

    if SelectedOnly and (not Selected[Node]) then
    begin
      Node := GetNext(Node);
      Continue;
    end;

    if ((NodeTypes = ntChart) and (NodeData.Chart = nil)) or
       ((NodeTypes = ntStream) and (NodeData.Stream = nil)) then
    begin
      Node := GetNext(Node);
      Continue;
    end;

    SetLength(Result, Length(Result) + 1);
    Result[Length(Result) - 1] := Node;
    Node := GetNext(Node);
  end;
end;

function TChartsTree.NodesToData(Nodes: TNodeArray): TChartDataArray;
var
  i: Integer;
  Data: PChartNodeData;
begin
  SetLength(Result, Length(Nodes));
  for i := 0 to Length(Nodes) - 1 do
  begin
    Data := GetNodeData(Nodes[i]);
    Result[i] := Data;
  end;
end;

procedure TChartsTree.KeyPress(var Key: Char);
begin
  inherited;

  if (Key = #13) or (Key = #32) then
  begin
    Key := #0;
    ExecDefaultAction;
  end;
end;

procedure TChartsTree.OnSaveListNotify(Sender: TObject;
  const Item: TTitleInfo; Action: TCollectionNotification);
var
  Node: PVirtualNode;
  NodeData: PChartNodeData;
begin
  if Sender = FLists.SaveList then
  begin
    if (Action = cnAdded) or (Action = cnRemoved) then
    begin
      Node := GetFirst;
      while Node <> nil do
      begin
        NodeData := GetNodeData(Node);
        if (NodeData.Chart <> nil) and (LowerCase(NodeData.Chart.Name) = LowerCase(Item.Title)) then
        begin
          NodeData.IsOnWishlist := Action = cnAdded;
          InvalidateNode(Node);
          Break;
        end;
        Node := GetNext(Node);
      end;
    end;
  end;
end;

procedure TChartsTree.Paint;
var
  Msg: string;
begin
  inherited;

  SetBkMode(Canvas.Handle, TRANSPARENT);

  if RootNodeCount = 0 then
    case FState of
      csNormal: ;
      csLoading:
        begin
          Msg := _(TEXT_LOADING) + FDots;
          Canvas.TextOut(FTextLeft, ClientHeight div 2 - Canvas.TextHeight(Msg), Msg);
        end;
      csError:
        begin
          Msg := _(TEXT_ERROR);
          Canvas.TextOut(FTextLeft, ClientHeight div 2 - Canvas.TextHeight(Msg), Msg);
        end;
    end;
end;

procedure TChartsTree.PopupMenuClick(Sender: TObject);
var
  i: Integer;
  Nodes: TChartDataArray;
  Titles: TStringList;
  P: TControl;
  F: TfrmChartsTabAdjustTitleName;
  Info: TStartStreamingInfoArray;
begin
  P := Parent;
  while not (P.ClassType = TChartsTab) do
    P := P.Parent;

  Nodes := NodesToData(GetNodes(ntAll, True));

  Titles := TStringList.Create;
  SetLength(Info, 0);
  try
    for i := 0 to Length(Nodes) - 1 do
    begin
      if Nodes[i].Chart <> nil then
      begin
        if Sender = FPopupMenu.ItemAddToWishlist then
        begin
          Titles.Add(Nodes[i].Chart.Name);
        end else if Sender = FPopupMenu.ItemEditAndAddToWishlist then
        begin
          F := TfrmChartsTabAdjustTitleName.Create(GetParentForm(Self), Nodes[i].Chart.Name);
          try
            F.ShowModal;

            if F.Okay then
            begin
              Titles.Add(F.TitleName);
            end;
          finally
            F.Free;
          end;
        end;
      end else
      begin
        // TODO: R�ckgabewerte checken. was ist z.B., wenn nicht gestreamed wird, weil kein speicher/bandbreite mehr da ist?
        SetLength(Info, Length(Info) + 1);
        Info[High(Info)] := TStartStreamingInfo.Create(Nodes[i].Stream.ID, Nodes[i].Stream.Stream.Bitrate,
          Nodes[i].Stream.Stream.Name, Nodes[i].Stream.Stream.URL, Nodes[i].Stream.Stream.RegEx,
          Nodes[i].Stream.Stream.IgnoreTitles);
      end;
    end;

    if Sender = FPopupMenu.ItemStartStreaming then
      TChartsTab(P).FOnAddStreams(Self, Info, oaStart)
    else if Sender = FPopupMenu.ItemPlayStream then
      TChartsTab(P).FOnAddStreams(Self, Info, oaPlay)
    else if Sender = FPopupMenu.ItemPlayStreamExternal then
      TChartsTab(P).FOnAddStreams(Self, Info, oaPlayExternal)
    else if Sender = FPopupMenu.ItemAddStream then
      TChartsTab(P).FOnAddStreams(Self, Info, oaAdd);

    if Titles.Count > 0 then
      TChartsTab(P).FOnAddToWishlist(Self, Titles)
  finally
    Titles.Free;
  end;

  Invalidate;
end;

procedure TChartsTree.PopupMenuPopup(Sender: TObject);
var
  AllOnList: Boolean;
  N: PVirtualNode;
  NodeData: PChartNodeData;
begin
  inherited;

  AllOnList := True;

  N := GetFirst;
  while N <> nil do
  begin
    if Selected[N] then
    begin
      NodeData := GetNodeData(N);
      if not NodeData.IsOnWishlist then
      begin
        AllOnList := False;
        Break;
      end;
    end;
    N := GetNext(N);
  end;

  FPopupMenu.EnableItems(SelectedCount, AllOnList);
end;

procedure TChartsTree.Resize;
begin
  inherited;

  case FState of
    csLoading:
      FTextLeft := ClientWidth div 2 - Canvas.TextWidth(_(TEXT_LOADING) + '..') div 2;
    csError:
      FTextLeft := ClientWidth div 2 - Canvas.TextWidth(_(TEXT_ERROR)) div 2;
  end;
end;

procedure TChartsTree.TimerOnTimer(Sender: TObject);
begin
  FDots := FDots + '.';

  if Length(FDots) = 4 then
    FDots := '';

  Invalidate;
end;

{ TSearchPanel }

constructor TSearchPanel.Create(AOwner: TComponent);
begin
  inherited;

  BevelOuter := bvNone;

  FLabel := TLabel.Create(Self);
  FLabel.Parent := Self;
  FLabel.Caption := _('Search:');

  FSearch := TEdit.Create(Self);
  FSearch.Parent := Self;

  FCategories := TCategoryCombo.Create(Self);
  FCategories.Style := csDropDownList;
  FCategories.Parent := Self;

  FToolbar := TToolBar.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.ShowHint := True;
  FToolbar.Align := alCustom;
end;

procedure TSearchPanel.Resize;
begin
  inherited;

end;

procedure TSearchPanel.Setup(Images: TImageList);
begin
  FCategories.Left := 0;
  FCategories.Top := 2;

  FLabel.Top := 7;
  FLabel.Left := FCategories.Left + FCategories.Width + 8;

  FSearch.Width := 200;
  FSearch.Top := FCategories.Top;
  FSearch.Left := FLabel.Left + FLabel.Width + 4;

  ClientHeight := FSearch.Top + 6 + FSearch.Height;

  FToolbar.Images := Images;

  FButtonReload := TToolButton.Create(FToolbar);
  FButtonReload.Parent := FToolbar;
  FButtonReload.Hint := _('Refresh');
  FButtonReload.ImageIndex := 23;

  //FToolbar.Top := 2;
  //FToolbar.Left := ClientWidth - FButtonReload.Width - 2;
  FToolbar.Padding.Top := 2;
  FToolbar.Align := alRight;
  FToolbar.Width := FButtonReload.Width + 2;
end;

{ TChartsPopup }

constructor TChartsPopup.Create(AOwner: TComponent);
var
  Sep: TMenuItem;
begin
  inherited;

  FItemAddToWishlist := CreateMenuItem;
  FItemAddToWishlist.Caption := '&Add to wishlist';
  FItemAddToWishlist.ImageIndex := 31;
  FItemAddToWishlist.Default := True;
  Items.Add(FItemAddToWishlist);

  FItemEditAndAddToWishlist := CreateMenuItem;
  FItemEditAndAddToWishlist.Caption := '&Edit and add to wishlist';
  FItemEditAndAddToWishlist.ImageIndex := 30;
  Items.Add(FItemEditAndAddToWishlist);

  Sep := CreateMenuItem;
  Sep.Caption := '-';
  Items.Add(Sep);

  FItemStartStreaming := CreateMenuItem;
  FItemStartStreaming.Caption := '&Start recording';
  FItemStartStreaming.ImageIndex := 0;
  Items.Add(FItemStartStreaming);

  FItemPlayStream := CreateMenuItem;
  FItemPlayStream.Caption := '&Play stream';
  FItemPlayStream.ImageIndex := 33;
  Items.Add(FItemPlayStream);

  FItemPlayStreamExternal := CreateMenuItem;
  FItemPlayStreamExternal.Caption := 'P&lay stream (external player)';
  Items.Add(FItemPlayStreamExternal);

  FItemAddStream := CreateMenuItem;
  FItemAddStream.Caption := '&Add stream';
  FItemAddStream.ImageIndex := 80;
  Items.Add(FItemAddStream);
end;

procedure TChartsPopup.EnableItems(SelectedCount: Integer; AllOnList: Boolean);
var
  O: TChartsTree;
  SelectedCharts: TNodeArray;
  SelectedStreams: TNodeArray;
begin
  O := TChartsTree(Owner);

  SelectedCharts := O.GetNodes(ntChart, True);
  SelectedStreams := O.GetNodes(ntStream, True);

  FItemAddToWishlist.Enabled := Length(SelectedCharts) > 0;
  FItemEditAndAddToWishlist.Enabled := Length(SelectedCharts) = 1;

  FItemStartStreaming.Enabled := Length(SelectedStreams) > 0;
  FItemPlayStream.Enabled := Length(SelectedStreams) = 1;
  FItemPlayStreamExternal.Enabled := Length(SelectedStreams) = 1;
  FItemAddStream.Enabled := Length(SelectedStreams) > 0;
end;

{ TCategoryCombo }

procedure TCategoryCombo.LoadCategories(Categories: TList<TChartCategory>);
var
  i: Integer;
begin
  Items.Clear;

  Items.AddObject(_(TEXT_EVERYSONG), nil);

  for i := 0 to Categories.Count - 1 do
    Items.AddObject(Categories[i].Name, Categories[i]);

  ItemIndex := 0;
end;

procedure TCategoryCombo.PostTranslate;
var
  OldIdx: Integer;
begin
  if Items.Count > 0 then
  begin
    OldIdx := ItemIndex;
    if OldIdx = -1 then
      OldIdx := 0;

    ItemIndex := -1;
    Items[0] := _(TEXT_EVERYSONG);

    // Ja, das sieht doof aus, aber muss, damit sich die Caption �bersetzt!
    Application.ProcessMessages;
    ItemIndex := OldIdx;
    Application.ProcessMessages;
  end;
end;

end.

