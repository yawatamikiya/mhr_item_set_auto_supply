--[[

2022/09/01
item_set_auto_supply.lua by Yawata Mikiya

装備マイセットが選択されたときに自動的に紐づけられたアイテムマイセットをセットします。
また、拠点に戻ってきた際に適用するアイテムマイセットも選択することが出来ます。

]]

initial_complete = false
config_data = nil
equip_name_list = {}
item_name_list = {}

apply_item_return_village = false

equip_selected_index = 1
item_selected_index = 1
item_selected_index_when_returning = 1

FILE_NAME = "ItemEquipLink.json"

-- メッセージを通知する
local function SendMessage(text)

  -- チャットマネージャを取得
  local chatManager = sdk.get_managed_singleton("snow.gui.ChatManager")
  if not chatManager then
    return
  end

  -- メッセージを通知する
  chatManager:call("reqAddChatInfomation", text, 0)

end

-- アイテムマイセットを設定する
local function applyItemMySet(mySetIndex)

  -- データマネージャを取得する
  local data_manager = sdk.get_managed_singleton("snow.data.DataManager")
  if not data_manager then
    return
  end

  -- アイテムマイセットリストを取得する
  local item_data_list = data_manager:get_field("_ItemMySet")

  -- アイテムマイセットを適用する
  item_data_list:call("applyItemMySet", mySetIndex)

  -- アイテムマイセットデータを取得する
  local item_data = item_data_list:call("getData", mySetIndex)

  -- アイテムマイセットの名前を取得する
  local set_name = item_data:get_field("_Name")

  -- アイテムが不足しているかどうか
  local isEnough = item_data:call("isEnoughItem")
  if isEnough == true then

    -- アイテムマイセットを選択したことを通知する
    SendMessage("下記マイセットを選択しました。\n" .. set_name)

    return
  end

  -- 不足していることを通知する
  SendMessage("下記マイセットのアイテムに不足がありました。\n" .. set_name)

end

-- 装備マイセットインデックスからマイセット名を取得する
local function getEquipMySetName(target_set_index)

  -- 装備データマネージャを取得する
  local equip_manager = sdk.get_managed_singleton("snow.data.EquipDataManager")
  if not equip_manager then
    return nil
  end

  -- 装備マイセットリストを取得する
  local equip_list = equip_manager:get_field("_PlEquipMySetList")

  -- 指定したインデックスの装備マイセット名を取得する
  return equip_list:get_Item(target_set_index):get_field("_Name")

end

-- アイテムマイセットインデックスからマイセット名を取得する
local function getItemMySetName(target_set_index)

  -- データマネージャを取得する
  local data_manager = sdk.get_managed_singleton("snow.data.DataManager")
  if not data_manager then
    return -1
  end

  -- アイテムマイセットリストを取得する
  local item_data_list = data_manager:get_field("_ItemMySet")

  -- 指定したインデックスのアイテムマイセット名を取得する
  return item_data_list:call("getData", target_set_index):get_field("_Name")

end

-- アイテムマイセット名からインデックスを取得する
local function getItemMySetIndex(target_set_name)

  -- データマネージャを取得する
  local data_manager = sdk.get_managed_singleton("snow.data.DataManager")
  if not data_manager then
    return -1
  end

  -- アイテムマイセットリストを取得する
  local item_data_list = data_manager:get_field("_ItemMySet")

  -- アイテムマイセットの個数を取得する
  local item_my_set_count = item_data_list:get_field("ListNum")

  -- 指定したアイテムマイセット名に一致するインデックスを取得する
  index = -1
  for i = 1 , item_my_set_count do

    -- アイテムマイセットを取得する
    local item_my_set = item_data_list:call("getData", i - 1)

    -- アイテムマイセットの名前を取得する
    local set_name = item_my_set:get_field("_Name")
    if target_set_name == set_name then
      index = i
      break
    end
  end

  return index
end

-- マイセット名リストを取得する
local function get_my_set_name_list()

  -- 装備データマネージャを取得する
  local equip_manager = sdk.get_managed_singleton("snow.data.EquipDataManager")
  if not equip_manager then
    return
  end

  -- 装備マイセットリストを取得する
  local equip_list = equip_manager:get_field("_PlEquipMySetList")

  -- 装備マイセット名リストを取得する
  local equip_name_list_temp = {}
  for i = 1, 112 do
    equip_name_list_temp[i] = equip_list:get_Item(i - 1):get_field("_Name")
  end

  -- データマネージャを取得する
  local data_manager = sdk.get_managed_singleton("snow.data.DataManager")
  if not data_manager then
    return
  end

  -- アイテムマイセットリストを取得する
  local item_data_list = data_manager:get_field("_ItemMySet")

  -- アイテムマイセット名リストを取得する
  local item_name_list_temp = {}
  for i = 1, 40 do
    item_name_list_temp[i] = item_data_list:call("getData", i - 1):get_field("_Name")
  end

  return equip_name_list_temp, item_name_list_temp

end

-- マイセット装備を選択した際に発生するイベントのフック
sdk.hook(
  sdk.find_type_definition("snow.data.EquipDataManager"):get_method("applyEquipMySet(System.Int32)"),
  function(args)

    -- 選択された装備マイセットインデックスを取得する
    local equip_index = sdk.to_int64(args[3])

    -- 設定ファイルを読み込む
    config_data = json.load_file(FILE_NAME)
    if config_data == nil then
      config_data = {ApplyItemWhenReturning = {Enable = false, Name = ""}, MySet = {}}
    end

    if config_data["MySet"] == nil then
      config_data["MySet"] = {}
    end

    if config_data["ApplyItemWhenReturning"] == nil then
      config_data["ApplyItemWhenReturning"] = {Enable = false, Name = ""}
    end

    -- 装備マイセット名を取得する
    local my_set_name = getEquipMySetName(equip_index)

    -- マイセット装備 <-> アイテムマイセット の紐づけを取得する
    for no, value in pairs(config_data["MySet"]) do

      -- 一致する装備マイセットインデックスが存在するか確認する
      if value.Equip == my_set_name then

        -- 設定ファイルで指定されたアイテムマイセットのインデックスを取得する
        -- lua形式のインデックスから.Net形式に合わせるために-1する
        local my_set_index = getItemMySetIndex(value.Item) - 1

        -- 対応するアイテムマイセットを適用する
        applyItemMySet(my_set_index)

        break

      end
    end
  end
)

-- 装備マイセットを追加した時に発生するイベントのフック
sdk.hook(
  sdk.find_type_definition("snow.data.EquipDataManager"):get_method("registerEquipMySet(System.Int32)"),
  function(args)

    -- 初回処理実行フラグOFF
    initial_complete = false

  end
)

-- 装備マイセットを削除した時に発生するイベントのフック
sdk.hook(
  sdk.find_type_definition("snow.data.EquipDataManager"):get_method("deleteEquipMySet(System.Int32)"),
  function(args)

    -- 初回処理実行フラグOFF
    initial_complete = false

  end
)

-- アイテムマイセットを選択した際に発生するイベントのフック
sdk.hook(
  sdk.find_type_definition("snow.data.DataManager"):get_method("applyItemMySet(System.Int32)"),
  function(args)

    -- 初回処理実行フラグOFF
    initial_complete = false
    
  end
)

-- アイテムマイセットを追加した時に発生するイベントのフック
sdk.hook(
  sdk.find_type_definition("snow.data.DataManager"):get_method("registerItemMySet(System.Int32)"),
  function(args)

    -- 初回処理実行フラグOFF
    initial_complete = false

  end
)

-- アイテムマイセットを削除した時に発生するイベントのフック
sdk.hook(
  sdk.find_type_definition("snow.data.DataManager"):get_method("deleteItemMySet(System.Int32)"),
  function(args)

    -- 初回処理実行フラグOFF
    initial_complete = false

  end
)

-- 拠点帰還時に発生するイベントのフック
sdk.hook(
  sdk.find_type_definition("snow.gui.GuiManager"):get_method("notifyReturnInVillage"),
  function(args)
      
    if apply_item_return_village == true then

      -- 現在選択されているアイテムマイセットを適用する
      if item_selected_index_when_returning ~= -1 then
        applyItemMySet(item_selected_index_when_returning - 1)
      end
    end
  end
)

-- 設定変更処理を行うUIの実装
re.on_draw_ui(
  function()

    -- ツリーを追加する
    if imgui.tree_node("Item-Auto-Supply Configure") then

      local is_initial = false
      if initial_complete == false then

        -- 日本語フォントを指定する
        imgui.push_font("ItemEquipLink\\unifont_jp-14.0.01.ttf")

        -- マイセット名リストを取得する
        equip_name_list, item_name_list = get_my_set_name_list()

        -- インデックスをリセットする
        equip_selected_index = 1
        item_selected_index = 1

        -- 設定ファイルを読み込む
        config_data = json.load_file(FILE_NAME)
        if config_data == nil then
          config_data = {ApplyItemWhenReturning = {Enable = false, Name = ""}, MySet = {}}
        end

        if config_data["MySet"] == nil then
          config_data["MySet"] = {}
        end

        if config_data["ApplyItemWhenReturning"] == nil then
          config_data["ApplyItemWhenReturning"] = {Enable = false, Name = ""}
        end

        -- 設定を反映する
        apply_item_return_village = config_data["ApplyItemWhenReturning"]["Enable"]

        -- 帰還時適用アイテムマイセットを名前から検索する
        local index_temp = getItemMySetIndex(config_data["ApplyItemWhenReturning"]["Name"])
        if index_temp ~= -1 then
          item_selected_index_when_returning = index_temp
        end

        -- 初回処理実行フラグON
        initial_complete = true

        -- 初回実行かどうか?
        is_initial = true
      end

      local my_set_index = -1

      -- 装備マイセット適用コンボボックス
      changed_equip, index = imgui.combo("Equip", equip_selected_index, equip_name_list)
      if changed_equip == true or is_initial == true then

        -- 設定ファイルを読み込む
        config_data = json.load_file(FILE_NAME)
        if config_data == nil then
          config_data = {ApplyItemWhenReturning = {Enable = false, Name = ""}, MySet = {}}
        end

        if config_data["MySet"] == nil then
          config_data["MySet"] = {}
        end

        if config_data["ApplyItemWhenReturning"] == nil then
          config_data["ApplyItemWhenReturning"] = {Enable = false, Name = ""}
        end

        -- インデックスを更新する
        equip_selected_index = index

        -- マイセット装備 <-> アイテムマイセット の紐づけを取得する
        for no, value in pairs(config_data["MySet"]) do

          -- 一致する装備マイセットインデックスが存在するか確認する
          if value.Equip == equip_name_list[index] then

            -- 設定ファイルで指定されたアイテムマイセットのインデックスを取得する
            -- アイテムマイセットインデックスとして設定する
            item_selected_index = getItemMySetIndex(value.Item)
            break
          end
        end
      end

      -- インデックスが不正の場合は先頭を指定する
      if item_selected_index < 1 or item_selected_index > 40 then
        item_selected_index = 1
      end

      -- アイテムマイセット適用コンボボックス
      changed_item, index = imgui.combo("Item", item_selected_index, item_name_list)
      if changed_item == true or changed_equip == true then

        if config_data == nil then
          -- 設定ファイルを読み込む
          config_data = json.load_file(FILE_NAME)
          if config_data == nil then
            config_data = {ApplyItemWhenReturning = {Enable = false, Name = ""}, MySet = {}}
          end
        end

        if config_data["MySet"] == nil then
          config_data["MySet"] = {}
        end

        if config_data["ApplyItemWhenReturning"] == nil then
          config_data["ApplyItemWhenReturning"] = {Enable = false, Name = ""}
        end

        -- インデックスを更新する
        item_selected_index = index

        -- 設定ファイルの情報を変更する
        index = 1
        my_set_data = config_data["MySet"]
        local is_found = false
        for no, value in pairs(config_data["MySet"]) do

          -- 一致する装備マイセットインデックスが存在するか確認する
          if value.Equip == equip_name_list[equip_selected_index] then

            -- MySetに値を追加する
            my_set_data[index]["Item"] = item_name_list[item_selected_index]

            -- 発見フラグをON
            is_found = true
            break
          end

          index = index + 1
        end

        -- 発見できなかった場合はテーブルに新たに値を追加する
        if is_found == false then
          table.insert(my_set_data, {Equip = equip_name_list[equip_selected_index], Item = item_name_list[item_selected_index]})
        end

        -- マイセットデータを戻す
        config_data["MySet"] = my_set_data

        -- ファイルを保存する
        json.dump_file(FILE_NAME, config_data)

      end

      -- アイテムマイセット適用チェックボックス(拠点帰還時用)
      changed, value = imgui.checkbox("Apply Item when returning", apply_item_return_village)
      if changed == true then

        -- 変更を反映する
        apply_item_return_village = value

        -- 設定ファイルを読み込む
        config_data = json.load_file(FILE_NAME)
        if config_data == nil then
          config_data = {ApplyItemWhenReturning = {Enable = false, Name = ""}, MySet = {}}
        end

        if config_data["MySet"] == nil then
          config_data["MySet"] = {}
        end

        if config_data["ApplyItemWhenReturning"] == nil then
          config_data["ApplyItemWhenReturning"] = {Enable = false, Name = ""}
        end

        -- 変更を反映する
        config_data["ApplyItemWhenReturning"]["Enable"] = apply_item_return_village

        -- ファイルを保存する
        json.dump_file(FILE_NAME, config_data)

      end

      -- アイテムマイセット適用コンボボックス(拠点帰還時用)
      changed, index = imgui.combo("Item(Returning)", item_selected_index_when_returning, item_name_list)
      if changed == true  then

        -- 変更を反映する
        item_selected_index_when_returning = index

        -- 設定ファイルを読み込む
        config_data = json.load_file(FILE_NAME)
        if config_data == nil then
          config_data = {ApplyItemWhenReturning = {Enable = false, Name = ""}, MySet = {}}
        end

        if config_data["MySet"] == nil then
          config_data["MySet"] = {}
        end

        if config_data["ApplyItemWhenReturning"] == nil then
          config_data["ApplyItemWhenReturning"] = {Enable = false, Name = ""}
        end

        -- 変更を反映する
        config_data["ApplyItemWhenReturning"]["Name"] = getItemMySetName(index - 1)

        -- ファイルを保存する
        json.dump_file(FILE_NAME, config_data)
      end

      -- ツリーを追加した際に必要  
      imgui.tree_pop()
    end
  end
)


