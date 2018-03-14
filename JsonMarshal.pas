{*******************************************************}
{                                                       }
{       json序列/反序列化                               }
{       版权所有 (C) ying32                             }
{                                                       }
{*******************************************************}

unit JsonMarshal;


interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.JSON,
  MarshalCommon;

type

  TJsonMarshal = record
  strict private
    class procedure PostCallBack_Marshal(AJson: TJSONObject;
      ATypInfo: PTypeInfo; AInstance: Pointer; AKind: TNodeNameKind); static;
    class procedure PostCallBack_MarshalArray(AJson: TJSONArray;
      AValue: TValue; AInstance: Pointer; AKind: TNodeNameKind); static;

    class procedure PostCallBack_UnMarshal(AJson: TJSONObject;
      ATypInfo: PTypeInfo; AInstance: Pointer; AKind: TNodeNameKind); static;
    class procedure PostCallBack_UnMarshalArray(AJson: TJSONArray;
      AField: TRttiField; AInstance: Pointer; AKind: TNodeNameKind); static;

    class function JsonTryAs<T>(AJsonV: TJSONValue; APath: string = ''): T; static;
  public
    class function Marshal<T>(ARecord: T; out AResult: string;
      AKind: TNodeNameKind = nnkNormal): Boolean; static;
    class function UnMarshal<T>(AJsonStr: string; out AResult: T;
      AKind: TNodeNameKind = nnkNormal): Boolean; static;
    class function UnMarshalStream<T>(AJson: TStream; out AResult: T;
      AKind: TNodeNameKind = nnkNormal): Boolean; static;
  end;

implementation


uses
  System.Math;

class procedure TJsonMarshal.PostCallBack_Marshal(AJson: TJSONObject;
  ATypInfo: PTypeInfo; AInstance: Pointer; AKind: TNodeNameKind);
var
  LRT: TRttiRecordType;
  LRF: TRttiField;
  LJO: TJSONObject;
  LJA: TJSONArray;
  LName: string;
begin
  if (AJson = nil) or (ATypInfo = nil) or (AInstance = nil) then
    Exit;
  LRT := TRttiContext.Create.GetType(ATypInfo).AsRecord;
  for LRF in LRT.GetFields do
  begin
    case AKind of
      nnkLower : LName := LRF.Name.ToLower;
      nnkUpper : LName := LRF.Name.ToUpper;
    else
      LName := LRF.Name;
    end;
    case LRF.FieldType.TypeKind of
      tkRecord:
        begin
          LJO := TJSONObject.Create;
          PostCallBack_Marshal(LJO, LRF.FieldType.Handle, PByte(AInstance) + LRF.Offset, AKind);
          AJson.AddPair(LName, LJO);
        end;
      tkArray, tkDynArray:
        begin
          LJA := TJSONArray.Create;
          AJson.AddPair(LName, LJA);
          PostCallBack_MarshalArray(LJA, LRF.GetValue(AInstance), AInstance, AKind);;
        end;
      tkEnumeration :
        begin
          if LRF.GetValue(AInstance).AsBoolean then
            AJson.AddPair(LName, TJSONTrue.Create)
          else
            AJson.AddPair(LName, TJSONFalse.Create);
        end;
      tkUString, tkString, tkWString:
        AJson.AddPair(LName, TJSONString.Create(LRF.GetValue(AInstance).AsString));
      tkInteger:
        AJson.AddPair(LName, TJSONNumber.Create(LRF.GetValue(AInstance).AsInteger));
      tkInt64 :
        AJson.AddPair(LName, TJSONNumber.Create(LRF.GetValue(AInstance).AsInt64));
      tkFloat:
        AJson.AddPair(LName, TJSONNumber.Create(LRF.GetValue(AInstance).AsExtended));
    end;
  end;
end;

class procedure TJsonMarshal.PostCallBack_MarshalArray(AJson: TJSONArray;
  AValue: TValue; AInstance: Pointer; AKind: TNodeNameKind);
var
  LJO: TJSONObject;
  LV: TValue;
  I: Integer;
begin
  if (AJson = nil) or (AValue.IsEmpty) or (AInstance = nil) then
    Exit;
  for I := 0 to AValue.GetArrayLength - 1 do
  begin
    LV := AValue.GetArrayElement(I);
    case LV.Kind of
      tkRecord:
        begin
          LJO := TJSONObject.Create;
          PostCallBack_Marshal(LJO, LV.TypeInfo, LV.GetReferenceToRawData, AKind);
          AJson.AddElement(LJO);
        end;
      tkEnumeration :
        begin
          if LV.AsBoolean then
            AJson.AddElement(TJSONTrue.Create)
          else
            AJson.AddElement(TJSONFalse.Create);
        end;
      tkUString, tkString, tkWString:
        AJson.AddElement(TJSONString.Create(LV.AsString));
      tkInteger:
        AJson.AddElement(TJSONNumber.Create(LV.AsInteger));
      tkInt64 :
        AJson.AddElement(TJSONNumber.Create(LV.AsInt64));
      tkFloat:
        AJson.AddElement(TJSONNumber.Create(LV.AsExtended));
    end;
  end;
end;


class procedure TJsonMarshal.PostCallBack_UnMarshal(AJson: TJSONObject;
  ATypInfo: PTypeInfo; AInstance: Pointer; AKind: TNodeNameKind);
var
  LRT: TRttiRecordType;
  LRF: TRttiField;
  LName: string;
begin
  if (AJson = nil) or (ATypInfo = nil) or (AInstance = nil) then
    Exit;
  LRT := TRttiContext.Create.GetType(ATypInfo).AsRecord;
  for LRF in LRT.GetFields do
  begin
    case AKind of
      nnkLower : LName := LRF.Name.ToLower;
      nnkUpper : LName := LRF.Name.ToUpper;
    else
      LName := LRF.Name;
    end;
    case LRF.FieldType.TypeKind of
      tkRecord:
        PostCallBack_UnMarshal(JsonTryAs<TJSONObject>(AJson, LName),
          LRF.FieldType.Handle, PByte(AInstance) + LRF.Offset, AKind);
      tkArray, tkDynArray:
        PostCallBack_UnMarshalArray(JsonTryAs<TJSONArray>(AJson, LName),
          LRF, PByte(AInstance), AKind);
      tkEnumeration :
        LRF.SetValue(AInstance, JsonTryAs<Boolean>(AJson, LName));
      tkUString, tkString, tkWString:
        LRF.SetValue(AInstance, JsonTryAs<string>(AJson, LName));
      tkInt64:
        LRF.SetValue(AInstance, JsonTryAs<Int64>(AJson, LName));
      tkInteger:
        LRF.SetValue(AInstance, JsonTryAs<Integer>(AJson, LName));
      tkFloat:
        LRF.SetValue(AInstance, JsonTryAs<Double>(AJson, LName));
    end;
  end;
end;

class procedure TJsonMarshal.PostCallBack_UnMarshalArray(AJson: TJSONArray;
  AField: TRttiField; AInstance: Pointer; AKind: TNodeNameKind);
var
  I: Integer;
  LArr: TArray<TValue>;
  LElType: TRttiType;
  LNewArrLen: Integer;
begin
  if (AJson = nil) or (AField = nil) or (AInstance = nil) or (AJSon.Count = 0) then
    Exit;
  LElType := nil;
  if AField.FieldType is TRttiDynamicArrayType then
     LElType := (AField.FieldType as TRttiDynamicArrayType).ElementType
  else if AField.FieldType is TRttiArrayType then
     LElType := (AField.FieldType as TRttiArrayType).ElementType;
  if LElType = nil then
    Exit;

  LNewArrLen := AJSon.Count;
  if AField.FieldType.TypeKind = tkArray then
    LNewArrLen := Min((AField.FieldType as TRttiArrayType).TotalElementCount, LNewArrLen);

  SetLength(LArr, LNewArrLen);
  for I := 0 to High(LArr) do
  begin
    case LElType.TypeKind of
      tkRecord:
        begin
          //TValue.Make(nil, LElType.Handle, LArr[I]);
          LArr[I] := LArr[I].Cast(LElType.Handle);
          PostCallBack_UnMarshal(JsonTryAs<TJSONObject>(AJson.Items[I]),
            LElType.Handle, LArr[I].GetReferenceToRawData, AKind);
        end;
      tkEnumeration :
        LArr[I] := JsonTryAs<Boolean>(AJson.Items[I]);
      tkUString, tkString, tkWString:
        LArr[I] := JsonTryAs<string>(AJson.Items[I]);
      tkInteger:
        LArr[I] := JsonTryAs<Integer>(AJson.Items[I]);
      tkInt64 :
        LArr[I] := JsonTryAs<Int64>(AJson.Items[I]);
      tkFloat:
        LArr[I] := JsonTryAs<Double>(AJson.Items[I]);
    end;
  end;
  AField.SetValue(AInstance, TValue.FromArray(AField.FieldType.Handle, LArr));
end;


class function TJsonMarshal.JsonTryAs<T>(AJsonV: TJSONValue; APath: string): T;
type PT = ^T;
var LResult: NativeUInt;
begin
  if not AJsonV.TryGetValue<T>(APath, Result) then
  begin
    LResult := 0;
	Result := PT(@LResult)^;
  end;
end;

class function TJsonMarshal.Marshal<T>(ARecord: T; out AResult: string;
   AKind: TNodeNameKind): Boolean;
var
  LJSON: TJSONObject;
begin
  Result := False;
  LJSON := TJSONObject.Create;
  try
    PostCallBack_Marshal(LJSON, TypeInfo(T), @ARecord, AKind);
    AResult := LJSON.ToString;
    Result := True;
  finally
    LJSON.Free;
  end;
end;


class function TJsonMarshal.UnMarshal<T>(AJsonStr: string; out AResult: T;
  AKind: TNodeNameKind): Boolean;
var
  LJSon: TJSONValue;
  LJO: TJSONObject;
begin
  Result := False;
  LJSon := TJSONObject.ParseJSONValue(AJsonStr);
  if Assigned(LJSon) then
  begin
    try
      if LJSon.TryGetValue<TJSONObject>(LJO) then
        PostCallBack_UnMarshal(LJO, TypeInfo(T), @AResult, AKind);
      Result := True;
    finally
      LJSon.Free;
    end;
  end;
end;

class function TJsonMarshal.UnMarshalStream<T>(AJson: TStream; out AResult: T;
  AKind: TNodeNameKind): Boolean;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create('', TEncoding.UTF8);
  try
    AJson.Position := 0;
    LStream.LoadFromStream(AJson);
    LStream.Position := 0;
    Result := UnMarshal<T>(LStream.DataString, AResult, AKind);
  finally
    LStream.Free;
  end;
end;


end.
