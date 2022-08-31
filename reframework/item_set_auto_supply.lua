--[[

AutoSupplyItem by Yawata Mikiya

装備マイセットが選択されたときに自動的に
紐づけられたアイテムマイセットをセットします。

]]

initial_complete = false
config_data = nil
equip_name_list = {}
item_name_list = {}

equip_selected_index = 1
item_selected_index = 1

FILE_NAME = "ItemEquipLink.json"

local function SendMessage(text)

  local chatManager = sdk.get_managed_singleton("snow.gui.ChatManager")
  if not chatManager then
    return
  end

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

-- マイセット装備を選択した際に発生するイベントのフック
sdk.hook(
    sdk.find_type_definition("snow.data.EquipDataManager"):get_method("applyEquipMySet(System.Int32)"),
    function(args)

      -- 選択された装備マイセットインデックスを取得する
      local equip_index = sdk.to_int64(args[3])

      -- 設定ファイルを読み込む
      config_data = json.load_file(FILE_NAME)

      -- 装備マイセット名を取得する
      local my_set_name = getEquipMySetName(equip_index)

      -- マイセット装備 <-> アイテムマイセット の紐づけを取得する
      for no, value in pairs(config_data) do

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

-- 設定変更処理を行うUIの実装
re.on_draw_ui(
  function()

    -- ツリーを追加する
    if imgui.tree_node("Item-Auto-Sppuly Configure") then

      local is_initial = false
      if initial_complete == false then

        -- 日本語フォントを指定する
        imgui.push_font("ItemEquipLink\\unifont_jp-14.0.01.ttf")

        -- マイセット名リストを取得する
        equip_name_list, item_name_list = get_my_set_name_list()

        -- インデックスをリセットする
        equip_selected_index = 1
        item_selected_index = 1

        -- 初回処理実行フラグON
        initial_complete = true

        -- 初回実行かどうか?
        is_initial = true
      end

      -- アップデートボタン
      if imgui.button("Update Configure") then

        -- 初回処理実行フラグOFF
        initial_complete = false

      end

      local my_set_index = -1

      -- 装備コンボボックス
      changed_equip, index = imgui.combo("Equip", equip_selected_index, equip_name_list)
      if changed_equip == true or is_initial == true then

        -- 設定ファイルを読み込む
        config_data = json.load_file(FILE_NAME)
        if config_data == nil then
          config_data = {}
        end

        -- インデックスを更新する
        equip_selected_index = index

        -- マイセット装備 <-> アイテムマイセット の紐づけを取得する
        for no, value in pairs(config_data) do

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

      -- アイテムコンボボックス
      changed_item, index = imgui.combo("Item", item_selected_index, item_name_list)
      if changed_item == true or changed_equip == true then

        if config_data == nil then
          -- 設定ファイルを読み込む
          config_data = json.load_file(FILE_NAME)
          if config_data == nil then
            config_data = {}
          end
        end

        -- インデックスを更新する
        item_selected_index = index

        -- 設定ファイルの情報を変更する
        index = 1
        my_set_data = config_data
        local is_found = false
        for no, value in pairs(config_data) do

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

        -- ファイルを保存する
        json.dump_file(FILE_NAME, my_set_data)

      end

      -- ツリーを追加した際に必要  
      imgui.tree_pop()
    end
  end
)


