loadfile("./introtimework.lua")()
local action, sleep_time = ...
if sleep_time then
    if tonumber(sleep_time) then
        if tonumber(sleep_time) > 0 then
            os.execute('sleep ' .. sleep_time)
        end
    end
end
if action == 'sendmessage' then
    action, sleep_time, chat_id, parse_mode, text = ...
    text = text:gsub('\\"', '"')
    sendMessage(chat_id, text, parse_mode)
elseif action == 'forwardmessage' then
    action, sleep_time, chat_id, message_id = ...
    forwardMessage(chat_id, chat_id, message_id)
elseif action == 'deletemessage' then
    action, sleep_time, chat_id, message_id = ...
    if not deleteMessage(chat_id, message_id, true) then
        -- sendMessage(chat_id, langs[get_lang(chat_id)].cantDeleteMessage, false, message_id)
    end
elseif action == 'restrictuser' then
    action, sleep_time, chat_id, user_id, time = ...
    if time then
        restrictChatMember(chat_id, user_id, { can_send_messages = false, can_send_media_messages = false, can_send_other_messages = false, can_add_web_page_previews = false }, os.time() + time)
    else
        restrictChatMember(chat_id, user_id, { can_send_messages = false, can_send_media_messages = false, can_send_other_messages = false, can_add_web_page_previews = false })
    end
elseif action == 'kickuser' then
    action, sleep_time, chat_id, user_id = ...
    kickChatMember(user_id, chat_id, os.time() + 45)
elseif action == 'banuser' then
    action, sleep_time, chat_id, user_id, time = ...
    if time then
        kickChatMember(user_id, chat_id, os.time() + time)
    else
        kickChatMember(user_id, chat_id)
    end
end