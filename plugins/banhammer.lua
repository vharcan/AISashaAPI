﻿-- table to manage restrictions of a user in a keyboard
local restrictionsTable = {
    -- chat_id = { user_id = { restrictions } }
}
-- Empty tables for solving multiple problems(thanks to @topkecleon)
local cronTable = {
    -- temp table to not send the same error of kick again and again (just once per minute)
    kickBanErrors =
    {
        -- chat_id = error
    },
}

local function user_msgs(user_id, chat_id)
    local user_info
    local uhash = 'user:' .. user_id
    local user = redis_get_something(uhash)
    local um_hash = 'msgs:' .. user_id .. ':' .. chat_id
    user_info = tonumber(redis_get_something(um_hash) or 0)
    return user_info
end

local function kickinactive(executer, chat_id, num)
    local lang = get_lang(chat_id)
    local participants = getChatParticipants(chat_id)
    local kicked = 0
    for k, v in pairs(participants) do
        if v.user then
            v = v.user
            if tonumber(v.id) ~= tonumber(bot.id) and not is_mod2(v.id, chat_id, true) then
                local user_info = user_msgs(v.id, chat_id)
                if tonumber(user_info) < tonumber(num) then
                    kickUser(executer, v.id, chat_id, langs[lang].reasonInactive)
                    kicked = kicked + 1
                end
            end
        end
    end
    return langs[lang].massacre:gsub('X', kicked)
end

local function showRestrictions(chat_id, user_id, lang)
    local obj_user = getChatMember(chat_id, user_id)
    if type(obj_user) == 'table' then
        if obj_user.result then
            obj_user = obj_user.result
        else
            obj_user = nil
        end
    else
        obj_user = nil
    end
    if obj_user then
        if obj_user.status ~= 'creator' then
            if obj_user.status == 'restricted' then
                local text = langs[lang].restrictions ..
                langs[lang].restrictionSendMessages .. tostring(obj_user.can_send_messages) ..
                langs[lang].restrictionSendMediaMessages .. tostring(obj_user.can_send_media_messages) ..
                langs[lang].restrictionSendOtherMessages .. tostring(obj_user.can_send_other_messages) ..
                langs[lang].restrictionAddWebPagePreviews .. tostring(obj_user.can_add_web_page_previews)
                return text
            elseif obj_user.status == 'member' then
                local text = langs[lang].restrictions ..
                langs[lang].restrictionSendMessages .. tostring(true) ..
                langs[lang].restrictionSendMediaMessages .. tostring(true) ..
                langs[lang].restrictionSendOtherMessages .. tostring(true) ..
                langs[lang].restrictionAddWebPagePreviews .. tostring(true)
                return text
            else
                return langs[lang].errorTryAgain
            end
        else
            return langs[lang].errorTryAgain
        end
    else
        return langs[lang].errorTryAgain
    end
end

local function userRestrictions(chat_id, user_id)
    local obj_user = getChatMember(chat_id, user_id)
    if type(obj_user) == 'table' then
        if obj_user.result then
            obj_user = obj_user.result
            if obj_user.status == 'creator' or obj_user.status == 'left' or obj_user.status == 'kicked' then
                obj_user = nil
            end
        else
            obj_user = nil
        end
    else
        obj_user = nil
    end
    if obj_user then
        return adjustRestrictions(obj_user)
    end
end

local function run(msg, matches)
    if not msg.service then
        if msg.cb then
            if matches[2] == 'DELETE' then
                if not deleteMessage(msg.chat.id, msg.message_id, true) then
                    editMessageText(msg.chat.id, msg.message_id, langs[msg.lang].stop)
                end
            elseif matches[2] == 'BACK' then
                answerCallbackQuery(msg.cb_id, langs[msg.lang].keyboardUpdated, false)
                local chat_name = ''
                if data[tostring(matches[4])] then
                    chat_name = data[tostring(matches[4])].name or ''
                end
                editMessageReplyMarkup(msg.chat.id, msg.message_id, keyboard_restrictions_list(matches[4], matches[3], nil, matches[5] or false))
            elseif matches[2] == 'WHITELISTGBAN' then
                -- PUBLIC KEYBOARD
                if msg.from.is_owner then
                    local text = whitegban_user(msg.chat.id, matches[3]) .. '\n'
                    local status = getUserStatus(msg.chat.id, matches[3])
                    if status == 'kicked' then
                        text = text .. unbanUser(msg.from.id, matches[3], msg.chat.id)
                    elseif status == 'restricted' then
                        text = text .. unrestrictUser(msg.from.id, matches[3], msg.chat.id)
                    end
                    answerCallbackQuery(msg.cb_id, text, true)
                    editMessageText(msg.chat.id, msg.message_id, text)
                    mystat(matches[1] .. matches[2] .. matches[3] .. matches[4])
                else
                    answerCallbackQuery(msg.cb_id, langs[msg.lang].require_owner, true)
                end
            elseif matches[2] == 'RESTRICT' then
                restrictionsTable[tostring(matches[5])] = restrictionsTable[tostring(matches[5])] or { }
                restrictionsTable[tostring(matches[5])][tostring(matches[3])] = restrictionsTable[tostring(matches[5])][tostring(matches[3])] or clone_table(default_restrictions)
                answerCallbackQuery(msg.cb_id, langs[msg.lang].ok, false)
                local chat_name = ''
                if data[tostring(matches[5])] then
                    chat_name = data[tostring(matches[5])].name or ''
                end
                if restrictionsDictionary[matches[4]:lower()] == 'can_send_messages' then
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])][restrictionsDictionary[matches[4]:lower()]] = false
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])]['can_send_media_messages'] = false
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])]['can_send_other_messages'] = false
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])]['can_add_web_page_previews'] = false
                end
                if restrictionsDictionary[matches[4]:lower()] == 'can_send_media_messages' then
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])][restrictionsDictionary[matches[4]:lower()]] = false
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])]['can_send_other_messages'] = false
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])]['can_add_web_page_previews'] = false
                end
                if restrictionsDictionary[matches[4]:lower()] == 'can_send_other_messages' then
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])][restrictionsDictionary[matches[4]:lower()]] = false
                end
                if restrictionsDictionary[matches[4]:lower()] == 'can_add_web_page_previews' then
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])][restrictionsDictionary[matches[4]:lower()]] = false
                end
                editMessageReplyMarkup(msg.chat.id, msg.message_id, keyboard_restrictions_list(matches[5], matches[3], restrictionsTable[tostring(matches[5])][tostring(matches[3])], matches[6] or false))
                mystat(matches[1] .. matches[2] .. matches[3] .. matches[4] .. matches[5])
            elseif matches[2] == 'UNRESTRICT' then
                restrictionsTable[tostring(matches[5])] = restrictionsTable[tostring(matches[5])] or { }
                restrictionsTable[tostring(matches[5])][tostring(matches[3])] = restrictionsTable[tostring(matches[5])][tostring(matches[3])] or clone_table(default_restrictions)
                answerCallbackQuery(msg.cb_id, langs[msg.lang].ok, false)
                local chat_name = ''
                if data[tostring(matches[5])] then
                    chat_name = data[tostring(matches[5])].name or ''
                end
                if restrictionsDictionary[matches[4]:lower()] == 'can_send_messages' then
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])][restrictionsDictionary[matches[4]:lower()]] = true
                end
                if restrictionsDictionary[matches[4]:lower()] == 'can_send_media_messages' then
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])]['can_send_messages'] = true
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])][restrictionsDictionary[matches[4]:lower()]] = true
                end
                if restrictionsDictionary[matches[4]:lower()] == 'can_send_other_messages' then
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])]['can_send_messages'] = true
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])]['can_send_media_messages'] = true
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])][restrictionsDictionary[matches[4]:lower()]] = true
                end
                if restrictionsDictionary[matches[4]:lower()] == 'can_add_web_page_previews' then
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])]['can_send_messages'] = true
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])]['can_send_media_messages'] = true
                    restrictionsTable[tostring(matches[5])][tostring(matches[3])][restrictionsDictionary[matches[4]:lower()]] = true
                end
                editMessageReplyMarkup(msg.chat.id, msg.message_id, keyboard_restrictions_list(matches[5], matches[3], restrictionsTable[tostring(matches[5])][tostring(matches[3])], matches[6] or false))
                mystat(matches[1] .. matches[2] .. matches[3] .. matches[4] .. matches[5])
            elseif matches[2] == 'RESTRICTIONSDONE' then
                restrictionsTable[tostring(matches[4])] = restrictionsTable[tostring(matches[4])] or { }
                restrictionsTable[tostring(matches[4])][tostring(matches[3])] = restrictionsTable[tostring(matches[4])][tostring(matches[3])] or clone_table(default_restrictions)
                if is_mod2(msg.from.id, matches[4]) then
                    local obj_user = getChatMember(matches[4], matches[3])
                    if type(obj_user) == 'table' then
                        if obj_user.result then
                            obj_user = obj_user.result
                            if obj_user.status == 'creator' or obj_user.status == 'left' or obj_user.status == 'kicked' then
                                obj_user = nil
                            end
                        else
                            obj_user = nil
                        end
                    else
                        obj_user = nil
                    end
                    if obj_user then
                        local txt = restrictUser(msg.from.id, matches[3], matches[4], restrictionsTable[tostring(matches[4])][tostring(matches[3])])
                        answerCallbackQuery(msg.cb_id, txt, false)
                        restrictionsTable[tostring(matches[4])][tostring(matches[3])] = nil
                        editMessageText(msg.chat.id, msg.message_id, txt)
                    end
                    mystat(matches[1] .. matches[2] .. matches[3] .. matches[4])
                else
                    editMessageText(msg.chat.id, msg.message_id, langs[msg.lang].require_mod)
                end
            elseif matches[2] == 'TEMPBAN' then
                local time = tonumber(matches[3])
                local chat_name = ''
                if data[tostring(matches[6])] then
                    chat_name = data[tostring(matches[6])].name or ''
                end
                if matches[4] == 'BACK' then
                    answerCallbackQuery(msg.cb_id, langs[msg.lang].keyboardUpdated, false)
                    editMessageReplyMarkup(msg.chat.id, msg.message_id, keyboard_time('banhammer', matches[2], matches[6], matches[5], time, matches[7] or false))
                elseif matches[4] == 'SECONDS' or matches[4] == 'MINUTES' or matches[4] == 'HOURS' or matches[4] == 'DAYS' or matches[4] == 'WEEKS' then
                    local seconds, minutes, hours, days, weeks = unixToDate(time)
                    if matches[4] == 'SECONDS' then
                        if tonumber(matches[5]) == 0 then
                            answerCallbackQuery(msg.cb_id, langs[msg.lang].secondsReset, false)
                            time = time - dateToUnix(seconds, 0, 0, 0, 0)
                        else
                            if (time + dateToUnix(tonumber(matches[5]), 0, 0, 0, 0)) >= 0 then
                                time = time + dateToUnix(tonumber(matches[5]), 0, 0, 0, 0)
                            else
                                answerCallbackQuery(msg.cb_id, langs[msg.lang].errorTimeRange, true)
                            end
                        end
                    elseif matches[4] == 'MINUTES' then
                        if tonumber(matches[5]) == 0 then
                            answerCallbackQuery(msg.cb_id, langs[msg.lang].minutesReset, false)
                            time = time - dateToUnix(0, minutes, 0, 0, 0)
                        else
                            if (time + dateToUnix(0, tonumber(matches[5]), 0, 0, 0)) >= 0 then
                                time = time + dateToUnix(0, tonumber(matches[5]), 0, 0, 0)
                            else
                                answerCallbackQuery(msg.cb_id, langs[msg.lang].errorTimeRange, true)
                            end
                        end
                    elseif matches[4] == 'HOURS' then
                        if tonumber(matches[5]) == 0 then
                            answerCallbackQuery(msg.cb_id, langs[msg.lang].hoursReset, false)
                            time = time - dateToUnix(0, 0, hours, 0, 0)
                        else
                            if (time + dateToUnix(0, 0, tonumber(matches[5]), 0, 0)) >= 0 then
                                time = time + dateToUnix(0, 0, tonumber(matches[5]), 0, 0)
                            else
                                answerCallbackQuery(msg.cb_id, langs[msg.lang].errorTimeRange, true)
                            end
                        end
                    elseif matches[4] == 'DAYS' then
                        if tonumber(matches[5]) == 0 then
                            answerCallbackQuery(msg.cb_id, langs[msg.lang].daysReset, false)
                            time = time - dateToUnix(0, 0, 0, days, 0)
                        else
                            if (time + dateToUnix(0, 0, 0, tonumber(matches[5]), 0)) >= 0 then
                                time = time + dateToUnix(0, 0, 0, tonumber(matches[5]), 0)
                            else
                                answerCallbackQuery(msg.cb_id, langs[msg.lang].errorTimeRange, true)
                            end
                        end
                    elseif matches[4] == 'WEEKS' then
                        if tonumber(matches[5]) == 0 then
                            answerCallbackQuery(msg.cb_id, langs[msg.lang].weeksReset, false)
                            time = time - dateToUnix(0, 0, 0, 0, weeks)
                        else
                            if (time + dateToUnix(0, 0, 0, 0, tonumber(matches[5]))) >= 0 then
                                time = time + dateToUnix(0, 0, 0, 0, tonumber(matches[5]))
                            else
                                answerCallbackQuery(msg.cb_id, langs[msg.lang].errorTimeRange, true)
                            end
                        end
                    end
                    editMessageReplyMarkup(msg.chat.id, msg.message_id, keyboard_time('banhammer', matches[2], matches[6], matches[7], time, matches[8] or false))
                    mystat(matches[1] .. matches[2] .. matches[3] .. matches[4] .. matches[5] .. matches[6] .. matches[7])
                elseif matches[4] == 'DONE' then
                    local text = banUser(msg.from.id, matches[5], matches[6], '', time)
                    answerCallbackQuery(msg.cb_id, text, false)
                    sendMessage(matches[6], text)
                    if not deleteMessage(msg.chat.id, msg.message_id, true) then
                        editMessageText(msg.chat.id, msg.message_id, langs[msg.lang].stop)
                    end
                    mystat(matches[1] .. matches[2] .. matches[3] .. matches[4] .. matches[5] .. matches[6])
                end
            elseif matches[2] == 'TEMPRESTRICT' then
                local time = tonumber(matches[3])
                local chat_name = ''
                if data[tostring(matches[6])] then
                    chat_name = data[tostring(matches[6])].name or ''
                end
                if matches[4] == 'BACK' then
                    answerCallbackQuery(msg.cb_id, langs[msg.lang].keyboardUpdated, false)
                    restrictionsTable[tostring(matches[6])] = restrictionsTable[tostring(matches[6])] or { }
                    restrictionsTable[tostring(matches[6])][tostring(matches[5])] = restrictionsTable[tostring(matches[6])][tostring(matches[5])] or clone_table(default_restrictions)
                    editMessageReplyMarkup(msg.chat.id, msg.message_id, keyboard_time('banhammer', matches[2], matches[6], matches[5], time, matches[7] or false))
                elseif matches[4] == 'SECONDS' or matches[4] == 'MINUTES' or matches[4] == 'HOURS' or matches[4] == 'DAYS' or matches[4] == 'WEEKS' then
                    restrictionsTable[tostring(matches[6])] = restrictionsTable[tostring(matches[6])] or { }
                    restrictionsTable[tostring(matches[6])][tostring(matches[5])] = restrictionsTable[tostring(matches[6])][tostring(matches[5])] or clone_table(default_restrictions)
                    if restrictionsTable[tostring(matches[6])][tostring(matches[7])] then
                        local seconds, minutes, hours, days, weeks = unixToDate(time)
                        if matches[4] == 'SECONDS' then
                            if tonumber(matches[5]) == 0 then
                                answerCallbackQuery(msg.cb_id, langs[msg.lang].secondsReset, false)
                                time = time - dateToUnix(seconds, 0, 0, 0, 0)
                            else
                                if (time + dateToUnix(tonumber(matches[5]), 0, 0, 0, 0)) >= 0 then
                                    time = time + dateToUnix(tonumber(matches[5]), 0, 0, 0, 0)
                                else
                                    answerCallbackQuery(msg.cb_id, langs[msg.lang].errorTimeRange, true)
                                end
                            end
                        elseif matches[4] == 'MINUTES' then
                            if tonumber(matches[5]) == 0 then
                                answerCallbackQuery(msg.cb_id, langs[msg.lang].minutesReset, false)
                                time = time - dateToUnix(0, minutes, 0, 0, 0)
                            else
                                if (time + dateToUnix(0, tonumber(matches[5]), 0, 0, 0)) >= 0 then
                                    time = time + dateToUnix(0, tonumber(matches[5]), 0, 0, 0)
                                else
                                    answerCallbackQuery(msg.cb_id, langs[msg.lang].errorTimeRange, true)
                                end
                            end
                        elseif matches[4] == 'HOURS' then
                            if tonumber(matches[5]) == 0 then
                                answerCallbackQuery(msg.cb_id, langs[msg.lang].hoursReset, false)
                                time = time - dateToUnix(0, 0, hours, 0, 0)
                            else
                                if (time + dateToUnix(0, 0, tonumber(matches[5]), 0, 0)) >= 0 then
                                    time = time + dateToUnix(0, 0, tonumber(matches[5]), 0, 0)
                                else
                                    answerCallbackQuery(msg.cb_id, langs[msg.lang].errorTimeRange, true)
                                end
                            end
                        elseif matches[4] == 'DAYS' then
                            if tonumber(matches[5]) == 0 then
                                answerCallbackQuery(msg.cb_id, langs[msg.lang].daysReset, false)
                                time = time - dateToUnix(0, 0, 0, days, 0)
                            else
                                if (time + dateToUnix(0, 0, 0, tonumber(matches[5]), 0)) >= 0 then
                                    time = time + dateToUnix(0, 0, 0, tonumber(matches[5]), 0)
                                else
                                    answerCallbackQuery(msg.cb_id, langs[msg.lang].errorTimeRange, true)
                                end
                            end
                        elseif matches[4] == 'WEEKS' then
                            if tonumber(matches[5]) == 0 then
                                answerCallbackQuery(msg.cb_id, langs[msg.lang].weeksReset, false)
                                time = time - dateToUnix(0, 0, 0, 0, weeks)
                            else
                                if (time + dateToUnix(0, 0, 0, 0, tonumber(matches[5]))) >= 0 then
                                    time = time + dateToUnix(0, 0, 0, 0, tonumber(matches[5]))
                                else
                                    answerCallbackQuery(msg.cb_id, langs[msg.lang].errorTimeRange, true)
                                end
                            end
                        end
                        editMessageReplyMarkup(msg.chat.id, msg.message_id, keyboard_time('banhammer', matches[2], matches[6], matches[7], time, matches[8] or false))
                        mystat(matches[1] .. matches[2] .. matches[3] .. matches[4] .. matches[5] .. matches[6] .. matches[7])
                    else
                        editMessageText(msg.chat.id, msg.message_id, langs[msg.lang].errorTryAgain)
                    end
                elseif matches[4] == 'DONE' then
                    restrictionsTable[tostring(matches[6])] = restrictionsTable[tostring(matches[6])] or { }
                    restrictionsTable[tostring(matches[6])][tostring(matches[5])] = restrictionsTable[tostring(matches[6])][tostring(matches[5])] or clone_table(default_restrictions)
                    if restrictionsTable[tostring(matches[6])][tostring(matches[5])] then
                        local restrictions = restrictionsTable[tostring(matches[6])][tostring(matches[5])]
                        local txt = restrictUser(msg.from.id, matches[6], matches[5], restrictions, time)
                        answerCallbackQuery(msg.cb_id, txt, false)
                        restrictionsTable[tostring(matches[6])][tostring(matches[5])] = nil
                        sendMessage(matches[6], txt)
                        if not deleteMessage(msg.chat.id, msg.message_id, true) then
                            editMessageText(msg.chat.id, msg.message_id, langs[msg.lang].stop)
                        end
                        mystat(matches[1] .. matches[2] .. matches[3] .. matches[4] .. matches[5] .. matches[6])
                    else
                        editMessageText(msg.chat.id, msg.message_id, langs[msg.lang].errorTryAgain)
                    end
                end
            end
            return
        end

        if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
            if matches[1]:lower() == 'invite' then
                if msg.from.is_mod then
                    mystat('/invite')
                    local inviter = nil
                    if msg.from.username then
                        inviter = '@' .. msg.from.username .. ' [' .. msg.from.id .. ']'
                    else
                        inviter = msg.from.print_name:gsub("_", " ") .. ' [' .. msg.from.id .. ']'
                    end
                    local link = nil
                    local group_link = data[tostring(msg.chat.id)].link
                    if group_link then
                        link = inviter .. langs[msg.lang].invitedYouTo .. " <a href=\"" .. group_link .. "\">" .. html_escape((data[tostring(msg.chat.id)].name or '')) .. "</a>"
                    end
                    if msg.reply then
                        if matches[2] then
                            if matches[2]:lower() == 'from' then
                                if msg.reply_to_message.forward then
                                    if msg.reply_to_message.forward_from then
                                        if not globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.forward_from.id)] or is_admin(msg) then
                                            if not userInChat(msg.chat.id, msg.reply_to_message.forward_from.id, true) then
                                                if sendMessage(msg.reply_to_message.forward_from.id, link, 'html') then
                                                    globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.forward_from.id)] = true
                                                    return langs[msg.lang].ok
                                                else
                                                    return langs[msg.lang].noObjectInvite
                                                end
                                            else
                                                return langs[msg.lang].userAlreadyInChat
                                            end
                                        else
                                            return langs[msg.lang].userAlreadyInvited
                                        end
                                    else
                                        return langs[msg.lang].cantDoThisToChat
                                    end
                                else
                                    return langs[msg.lang].errorNoForward
                                end
                            else
                                if not globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.from.id)] or is_admin(msg) then
                                    if not userInChat(msg.chat.id, msg.reply_to_message.from.id, true) then
                                        if sendMessage(msg.reply_to_message.from.id, link, 'html') then
                                            globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.from.id)] = true
                                            return langs[msg.lang].ok
                                        else
                                            return langs[msg.lang].noObjectInvite
                                        end
                                    else
                                        return langs[msg.lang].userAlreadyInChat
                                    end
                                else
                                    return langs[msg.lang].userAlreadyInvited
                                end
                            end
                        else
                            if msg.reply_to_message.service then
                                if msg.reply_to_message.service_type == 'chat_del_user' then
                                    if not globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.removed.id)] or is_admin(msg) then
                                        if not userInChat(msg.chat.id, msg.reply_to_message.removed.id, true) then
                                            if sendMessage(msg.reply_to_message.removed.id, link, 'html') then
                                                globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.removed.id)] = true
                                                return langs[msg.lang].ok
                                            else
                                                return langs[msg.lang].noObjectInvite
                                            end
                                        else
                                            return langs[msg.lang].userAlreadyInChat
                                        end
                                    else
                                        return langs[msg.lang].userAlreadyInvited
                                    end
                                else
                                    if not globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.from.id)] or is_admin(msg) then
                                        if not userInChat(msg.chat.id, msg.reply_to_message.from.id, true) then
                                            if sendMessage(msg.reply_to_message.from.id, link, 'html') then
                                                globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.from.id)] = true
                                                return langs[msg.lang].ok
                                            else
                                                return langs[msg.lang].noObjectInvite
                                            end
                                        else
                                            return langs[msg.lang].userAlreadyInChat
                                        end
                                    else
                                        return langs[msg.lang].userAlreadyInvited
                                    end
                                end
                            else
                                if not globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.from.id)] or is_admin(msg) then
                                    if not userInChat(msg.chat.id, msg.reply_to_message.from.id, true) then
                                        if sendMessage(msg.reply_to_message.from.id, link, 'html') then
                                            globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.from.id)] = true
                                            return langs[msg.lang].ok
                                        else
                                            return langs[msg.lang].noObjectInvite
                                        end
                                    else
                                        return langs[msg.lang].userAlreadyInChat
                                    end
                                else
                                    return langs[msg.lang].userAlreadyInvited
                                end
                            end
                        end
                    elseif matches[2] and matches[2] ~= '' then
                        if msg.entities then
                            for k, v in pairs(msg.entities) do
                                -- check if there's a text_mention
                                if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                    if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                        if not globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.entities[k].user.id)] or is_admin(msg) then
                                            if not userInChat(msg.chat.id, msg.entities[k].user.id, true) then
                                                if sendMessage(msg.entities[k].user.id, link, 'html') then
                                                    globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(msg.entities[k].user.id)] = true
                                                    return langs[msg.lang].ok
                                                else
                                                    return langs[msg.lang].noObjectInvite
                                                end
                                            else
                                                return langs[msg.lang].userAlreadyInChat
                                            end
                                        else
                                            return langs[msg.lang].userAlreadyInvited
                                        end
                                    end
                                end
                            end
                        end
                        matches[2] = tostring(matches[2]):gsub(' ', '')
                        if string.match(matches[2], '^%d+$') then
                            if not globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(matches[2])] or is_admin(msg) then
                                if not userInChat(msg.chat.id, matches[2], true) then
                                    if sendMessage(matches[2], link, 'html') then
                                        globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(matches[2])] = true
                                        return langs[msg.lang].ok
                                    else
                                        return langs[msg.lang].noObjectInvite
                                    end
                                else
                                    return langs[msg.lang].userAlreadyInChat
                                end
                            else
                                return langs[msg.lang].userAlreadyInvited
                            end
                        else
                            local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                            if obj_user then
                                if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                    if not globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(obj_user.id)] or is_admin(msg) then
                                        if not userInChat(msg.chat.id, obj_user.id, true) then
                                            if sendMessage(obj_user.id, link, 'html') then
                                                globalCronTable.invitedTable[tostring(msg.chat.id)][tostring(obj_user.id)] = true
                                                return langs[msg.lang].ok
                                            else
                                                return langs[msg.lang].noObjectInvite
                                            end
                                        else
                                            return langs[msg.lang].userAlreadyInChat
                                        end
                                    else
                                        return langs[msg.lang].userAlreadyInvited
                                    end
                                end
                            else
                                return langs[msg.lang].noObject
                            end
                        end
                    end
                    return
                else
                    return langs[msg.lang].require_mod
                end
            end
            if matches[1]:lower() == 'kickme' then
                if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
                    savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] left using kickme ")
                    -- Save to logs
                    mystat('/kickme')
                    return kickUser(bot.id, msg.from.id, msg.chat.id, '#kickme')
                else
                    return langs[msg.lang].useYourGroups
                end
            end
            if matches[1]:lower() == 'getuserwarns' then
                if msg.from.is_mod then
                    if getWarn(msg.chat.id) == langs[msg.lang].noWarnSet then
                        return langs[msg.lang].noWarnSet
                    else
                        mystat('/getuserwarns')
                        if msg.reply then
                            if matches[2] then
                                if matches[2]:lower() == 'from' then
                                    if msg.reply_to_message.forward then
                                        if msg.reply_to_message.forward_from then
                                            return getUserWarns(msg.reply_to_message.forward_from.id, msg.chat.id)
                                        else
                                            return langs[msg.lang].cantDoThisToChat
                                        end
                                    else
                                        return langs[msg.lang].errorNoForward
                                    end
                                end
                            else
                                return getUserWarns(msg.reply_to_message.from.id, msg.chat.id)
                            end
                        elseif matches[2] and matches[2] ~= '' then
                            if msg.entities then
                                for k, v in pairs(msg.entities) do
                                    -- check if there's a text_mention
                                    if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                        if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                            return getUserWarns(msg.entities[k].user.id, msg.chat.id)
                                        end
                                    end
                                end
                            end
                            matches[2] = tostring(matches[2]):gsub(' ', '')
                            if string.match(matches[2], '^%d+$') then
                                return getUserWarns(matches[2], msg.chat.id)
                            else
                                local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                                if obj_user then
                                    if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                        return getUserWarns(obj_user.id, msg.chat.id)
                                    end
                                else
                                    return langs[msg.lang].noObject
                                end
                            end
                        end
                        return
                    end
                else
                    return langs[msg.lang].require_mod
                end
            end
            if matches[1]:lower() == 'muteuser' then
                if msg.from.is_mod then
                    mystat('/muteuser')
                    if msg.reply then
                        if matches[2] then
                            if matches[2]:lower() == 'from' then
                                if msg.reply_to_message.forward then
                                    if msg.reply_to_message.forward_from then
                                        -- ignore higher or same rank
                                        if compare_ranks(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id) then
                                            if isMutedUser(msg.chat.id, msg.reply_to_message.forward_from.id) then
                                                savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] removed [" .. msg.reply_to_message.forward_from.id .. "] from the muted users list")
                                                return unmuteUser(msg.chat.id, msg.reply_to_message.forward_from.id, msg.lang)
                                            else
                                                savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] added [" .. msg.reply_to_message.forward_from.id .. "] to the muted users list")
                                                return muteUser(msg.chat.id, msg.reply_to_message.forward_from.id, msg.lang)
                                            end
                                        else
                                            return langs[msg.lang].require_rank
                                        end
                                    else
                                        return langs[msg.lang].cantDoThisToChat
                                    end
                                else
                                    return langs[msg.lang].errorNoForward
                                end
                            end
                        else
                            -- ignore higher or same rank
                            if compare_ranks(msg.from.id, msg.reply_to_message.from.id, msg.chat.id) then
                                if isMutedUser(msg.chat.id, msg.reply_to_message.from.id) then
                                    savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] removed [" .. msg.reply_to_message.from.id .. "] from the muted users list")
                                    return unmuteUser(msg.chat.id, msg.reply_to_message.from.id, msg.lang)
                                else
                                    savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] added [" .. msg.reply_to_message.from.id .. "] to the muted users list")
                                    return muteUser(msg.chat.id, msg.reply_to_message.from.id, msg.lang)
                                end
                            else
                                return langs[msg.lang].require_rank
                            end
                        end
                    elseif matches[2] and matches[2] ~= '' then
                        if msg.entities then
                            for k, v in pairs(msg.entities) do
                                -- check if there's a text_mention
                                if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                    if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                        if compare_ranks(msg.from.id, msg.entities[k].user.id, msg.chat.id) then
                                            if isMutedUser(msg.chat.id, msg.entities[k].user.id) then
                                                savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] removed [" .. msg.entities[k].user.id .. "] from the muted users list")
                                                return unmuteUser(msg.chat.id, msg.entities[k].user.id, msg.lang)
                                            else
                                                savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] added [" .. msg.entities[k].user.id .. "] to the muted users list")
                                                return muteUser(msg.chat.id, msg.entities[k].user.id, msg.lang)
                                            end
                                        else
                                            return langs[msg.lang].require_rank
                                        end
                                    end
                                end
                            end
                        end
                        matches[2] = tostring(matches[2]):gsub(' ', '')
                        if string.match(matches[2], '^%d+$') then
                            -- ignore higher or same rank
                            if compare_ranks(msg.from.id, matches[2], msg.chat.id) then
                                if isMutedUser(msg.chat.id, matches[2]) then
                                    savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] removed [" .. matches[2] .. "] from the muted users list")
                                    return unmuteUser(msg.chat.id, matches[2], msg.lang)
                                else
                                    savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] added [" .. matches[2] .. "] to the muted users list")
                                    return muteUser(msg.chat.id, matches[2], msg.lang)
                                end
                            else
                                return langs[msg.lang].require_rank
                            end
                        else
                            local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                            if obj_user then
                                if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                    -- ignore higher or same rank
                                    if compare_ranks(msg.from.id, obj_user.id, msg.chat.id) then
                                        if isMutedUser(msg.chat.id, obj_user.id) then
                                            savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] removed [" .. obj_user.id .. "] from the muted users list")
                                            return unmuteUser(msg.chat.id, obj_user.id, msg.lang)
                                        else
                                            savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] added [" .. obj_user.id .. "] to the muted users list")
                                            return muteUser(msg.chat.id, obj_user.id, msg.lang)
                                        end
                                    else
                                        return langs[msg.lang].require_rank
                                    end
                                end
                            else
                                return langs[msg.lang].noObject
                            end
                        end
                    end
                    return
                else
                    return langs[msg.lang].require_mod
                end
            end
            if matches[1]:lower() == 'mutelist' then
                if msg.from.is_mod then
                    mystat('/mutelist')
                    savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] requested SuperGroup mutelist")
                    return mutedUserList(msg.chat.id)
                else
                    return langs[msg.lang].require_mod
                end
            end
            if matches[1]:lower() == 'warn' then
                if msg.from.is_mod then
                    if getWarn(msg.chat.id) == langs[msg.lang].noWarnSet then
                        return langs[msg.lang].noWarnSet
                    else
                        mystat('/warn')
                        if msg.reply then
                            if matches[2] then
                                if matches[2]:lower() == 'from' then
                                    if msg.reply_to_message.forward then
                                        if msg.reply_to_message.forward_from then
                                            return warnUser(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id, matches[3] or '')
                                        else
                                            return langs[msg.lang].cantDoThisToChat
                                        end
                                    else
                                        return langs[msg.lang].errorNoForward
                                    end
                                else
                                    return warnUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                end
                            else
                                if msg.reply_to_message.service then
                                    if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                                        local text = warnUser(msg.from.id, msg.reply_to_message.adder.id, msg.chat.id) .. '\n'
                                        for k, v in pairs(msg.reply_to_message.added) do
                                            text = text .. warnUser(msg.from.id, v.id, msg.chat.id) .. '\n'
                                        end
                                        return text ..(matches[2] or '') .. ' ' ..(matches[3] or '')
                                    elseif msg.reply_to_message.service_type == 'chat_del_user' then
                                        return warnUser(msg.from.id, msg.reply_to_message.removed.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                    else
                                        return warnUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                    end
                                else
                                    return warnUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                end
                            end
                        elseif matches[2] and matches[2] ~= '' then
                            if msg.entities then
                                for k, v in pairs(msg.entities) do
                                    -- check if there's a text_mention
                                    if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                        if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                            return warnUser(msg.from.id, msg.entities[k].user.id, msg.chat.id, matches[3] or '')
                                        end
                                    end
                                end
                            end
                            matches[2] = tostring(matches[2]):gsub(' ', '')
                            if string.match(matches[2], '^%d+$') then
                                return warnUser(msg.from.id, matches[2], msg.chat.id, matches[3] or '')
                            else
                                local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                                if obj_user then
                                    if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                        return warnUser(msg.from.id, obj_user.id, msg.chat.id, matches[3] or '')
                                    end
                                else
                                    return langs[msg.lang].noObject
                                end
                            end
                        end
                        return
                    end
                else
                    return langs[msg.lang].require_mod
                end
            end
            if matches[1]:lower() == 'unwarn' then
                if msg.from.is_mod then
                    if getWarn(msg.chat.id) == langs[msg.lang].noWarnSet then
                        return langs[msg.lang].noWarnSet
                    else
                        mystat('/unwarn')
                        if msg.reply then
                            if matches[2] then
                                if matches[2]:lower() == 'from' then
                                    if msg.reply_to_message.forward then
                                        if msg.reply_to_message.forward_from then
                                            return unwarnUser(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id, matches[3] or '')
                                        else
                                            return langs[msg.lang].cantDoThisToChat
                                        end
                                    else
                                        return langs[msg.lang].errorNoForward
                                    end
                                else
                                    return unwarnUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                end
                            else
                                if msg.reply_to_message.service then
                                    if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                                        local text = unwarnUser(msg.from.id, msg.reply_to_message.adder.id, msg.chat.id) .. '\n'
                                        for k, v in pairs(msg.reply_to_message.added) do
                                            text = text .. unwarnUser(msg.from.id, v.id, msg.chat.id) .. '\n'
                                        end
                                        return text ..(matches[2] or '') .. ' ' ..(matches[3] or '')
                                    elseif msg.reply_to_message.service_type == 'chat_del_user' then
                                        return unwarnUser(msg.from.id, msg.reply_to_message.removed.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                    else
                                        return unwarnUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                    end
                                else
                                    return unwarnUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                end
                            end
                        elseif matches[2] and matches[2] ~= '' then
                            if msg.entities then
                                for k, v in pairs(msg.entities) do
                                    -- check if there's a text_mention
                                    if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                        if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                            return unwarnUser(msg.from.id, msg.entities[k].user.id, msg.chat.id, matches[3] or '')
                                        end
                                    end
                                end
                            end
                            matches[2] = tostring(matches[2]):gsub(' ', '')
                            if string.match(matches[2], '^%d+$') then
                                return unwarnUser(msg.from.id, matches[2], msg.chat.id, matches[3] or '')
                            else
                                local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                                if obj_user then
                                    if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                        return unwarnUser(msg.from.id, obj_user.id, msg.chat.id, matches[3] or '')
                                    end
                                else
                                    return langs[msg.lang].noObject
                                end
                            end
                        end
                        return
                    end
                else
                    return langs[msg.lang].require_mod
                end
            end
            if matches[1]:lower() == 'unwarnall' then
                if msg.from.is_mod then
                    if getWarn(msg.chat.id) == langs[msg.lang].noWarnSet then
                        return langs[msg.lang].noWarnSet
                    else
                        mystat('/unwarnall')
                        if msg.reply then
                            if matches[2] then
                                if matches[2]:lower() == 'from' then
                                    if msg.reply_to_message.forward then
                                        if msg.reply_to_message.forward_from then
                                            return unwarnallUser(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id, matches[3] or '')
                                        else
                                            return langs[msg.lang].cantDoThisToChat
                                        end
                                    else
                                        return langs[msg.lang].errorNoForward
                                    end
                                else
                                    return unwarnallUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                end
                            else
                                if msg.reply_to_message.service then
                                    if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                                        local text = unwarnallUser(msg.from.id, msg.reply_to_message.adder.id, msg.chat.id) .. '\n'
                                        for k, v in pairs(msg.reply_to_message.added) do
                                            text = text .. unwarnallUser(msg.from.id, v.id, msg.chat.id) .. '\n'
                                        end
                                        return text ..(matches[2] or '') .. ' ' ..(matches[3] or '')
                                    elseif msg.reply_to_message.service_type == 'chat_del_user' then
                                        return unwarnallUser(msg.from.id, msg.reply_to_message.removed.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                    else
                                        return unwarnallUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                    end
                                else
                                    return unwarnallUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                end
                            end
                        elseif matches[2] and matches[2] ~= '' then
                            if msg.entities then
                                for k, v in pairs(msg.entities) do
                                    -- check if there's a text_mention
                                    if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                        if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                            return unwarnallUser(msg.from.id, msg.entities[k].user.id, msg.chat.id, matches[3] or '')
                                        end
                                    end
                                end
                            end
                            matches[2] = tostring(matches[2]):gsub(' ', '')
                            if string.match(matches[2], '^%d+$') then
                                return unwarnallUser(msg.from.id, matches[2], msg.chat.id, matches[3] or '')
                            else
                                local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                                if obj_user then
                                    if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                        return unwarnallUser(msg.from.id, obj_user.id, msg.chat.id, matches[3] or '')
                                    end
                                else
                                    return langs[msg.lang].noObject
                                end
                            end
                        end
                        return
                    end
                else
                    return langs[msg.lang].require_mod
                end
            end
            if tostring(msg.chat.id):starts('-100') then
                if matches[1]:lower() == 'temprestrict' then
                    if msg.from.is_mod then
                        restrictionsTable[tostring(msg.chat.id)] = restrictionsTable[tostring(msg.chat.id)] or { }
                        mystat('/restrict')
                        local restrictions = clone_table(default_restrictions)
                        local chat_name = ''
                        if data[tostring(msg.chat.id)] then
                            chat_name = data[tostring(msg.chat.id)].name or ''
                        end
                        local text = ''
                        if msg.reply then
                            if matches[2] then
                                if matches[2]:lower() == 'from' then
                                    if msg.reply_to_message.forward then
                                        if msg.reply_to_message.forward_from then
                                            local time = 0
                                            if matches[3] and matches[4] and matches[5] and matches[6] and matches[7] then
                                                time = dateToUnix(matches[7], matches[6], matches[5], matches[4], matches[3])
                                                if matches[8] then
                                                    restrictions = adjustRestrictions(matches[8]:lower())
                                                end
                                                return restrictUser(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id, restrictions, time)
                                            else
                                                if matches[3] then
                                                    restrictions = adjustRestrictions(matches[3]:lower())
                                                end
                                                restrictionsTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.forward_from.id)] = restrictions
                                                if sendKeyboard(msg.from.id, '(#user' .. tostring(msg.reply_to_message.forward_from.id) .. ') ' ..(database[tostring(msg.reply_to_message.forward_from.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPRESTRICT', msg.chat.id, msg.reply_to_message.forward_from.id)) then
                                                    if msg.chat.type ~= 'private' then
                                                        local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                        io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                        return
                                                    end
                                                else
                                                    return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                                end
                                            end
                                        else
                                            return langs[msg.lang].cantDoThisToChat
                                        end
                                    else
                                        return langs[msg.lang].errorNoForward
                                    end
                                else
                                    local time = 0
                                    if matches[2] and matches[3] and matches[4] and matches[5] and matches[6] then
                                        time = dateToUnix(matches[6], matches[5], matches[4], matches[3], matches[2])
                                        if matches[7] then
                                            restrictions = adjustRestrictions(matches[7]:lower())
                                        end
                                        return restrictUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id, restrictions, time)
                                    else
                                        if matches[2] then
                                            restrictions = adjustRestrictions(matches[2]:lower())
                                        end
                                        restrictionsTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.from.id)] = restrictions
                                        if sendKeyboard(msg.from.id, '(#user' .. tostring(msg.reply_to_message.from.id) .. ') ' ..(database[tostring(msg.reply_to_message.from.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPRESTRICT', msg.chat.id, msg.reply_to_message.from.id)) then
                                            if msg.chat.type ~= 'private' then
                                                local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                return
                                            end
                                        else
                                            return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                        end
                                    end
                                end
                            else
                                local time = 0
                                if matches[2] and matches[3] and matches[4] and matches[5] and matches[6] then
                                    time = dateToUnix(matches[6], matches[5], matches[4], matches[3], matches[2])
                                    if matches[7] then
                                        restrictions = adjustRestrictions(matches[7]:lower())
                                    end
                                    return restrictUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id, restrictions, time)
                                else
                                    if matches[2] then
                                        restrictions = adjustRestrictions(matches[2]:lower())
                                    end
                                    restrictionsTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.from.id)] = restrictions
                                    if sendKeyboard(msg.from.id, '(#user' .. tostring(msg.reply_to_message.from.id) .. ') ' ..(database[tostring(msg.reply_to_message.from.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPRESTRICT', msg.chat.id, msg.reply_to_message.from.id)) then
                                        if msg.chat.type ~= 'private' then
                                            local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                            io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                            return
                                        end
                                    else
                                        return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                    end
                                end
                            end
                        elseif matches[2] and matches[2] ~= '' then
                            local time = 0
                            if matches[3] and matches[4] and matches[5] and matches[6] and matches[7] then
                                time = dateToUnix(matches[7], matches[6], matches[5], matches[4], matches[3])
                                if msg.entities then
                                    for k, v in pairs(msg.entities) do
                                        -- check if there's a text_mention
                                        if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                            if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                                if matches[8] then
                                                    restrictions = adjustRestrictions(matches[8]:lower())
                                                end
                                                return restrictUser(msg.from.id, msg.entities[k].user.id, msg.chat.id, restrictions, time)
                                            end
                                        end
                                    end
                                end
                                matches[2] = tostring(matches[2]):gsub(' ', '')
                                local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                                if obj_user then
                                    if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                        if matches[8] then
                                            restrictions = adjustRestrictions(matches[8]:lower())
                                        end
                                        return restrictUser(msg.from.id, obj_user.id, msg.chat.id, restrictions, time)
                                    end
                                else
                                    return langs[msg.lang].noObject
                                end
                            else
                                if msg.entities then
                                    for k, v in pairs(msg.entities) do
                                        -- check if there's a text_mention
                                        if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                            if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                                if matches[3] then
                                                    restrictions = adjustRestrictions(matches[3]:lower())
                                                end
                                                restrictionsTable[tostring(msg.chat.id)][tostring(msg.entities[k].user.id)] = restrictions
                                                if sendKeyboard(msg.from.id, '(#user' .. tostring(msg.entities[k].user.id) .. ') ' ..(database[tostring(msg.entities[k].user.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPRESTRICT', msg.chat.id, msg.entities[k].user.id)) then
                                                    if msg.chat.type ~= 'private' then
                                                        local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                        io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                        return
                                                    end
                                                else
                                                    return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                                end
                                            end
                                        end
                                    end
                                end
                                matches[2] = tostring(matches[2]):gsub(' ', '')
                                if string.match(matches[2], '^%d+$') then
                                    if matches[3] then
                                        restrictions = adjustRestrictions(matches[3]:lower())
                                    end
                                    restrictionsTable[tostring(msg.chat.id)][tostring(matches[2])] = restrictions
                                    if sendKeyboard(msg.from.id, '(#user' .. tostring(matches[2]) .. ') ' ..(database[tostring(matches[2])]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPRESTRICT', msg.chat.id, matches[2])) then
                                        if msg.chat.type ~= 'private' then
                                            local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                            io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                            return
                                        end
                                    else
                                        return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                    end
                                else
                                    local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                                    if obj_user then
                                        if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                            if matches[3] then
                                                restrictions = adjustRestrictions(matches[3]:lower())
                                            end
                                            restrictionsTable[tostring(msg.chat.id)][tostring(obj_user.id)] = restrictions
                                            if sendKeyboard(msg.from.id, '(#user' .. tostring(obj_user.id) .. ') ' ..(database[tostring(obj_user.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPRESTRICT', msg.chat.id, obj_user.id)) then
                                                if msg.chat.type ~= 'private' then
                                                    local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                    io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                    return
                                                end
                                            else
                                                return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                            end
                                        end
                                    else
                                        return langs[msg.lang].noObject
                                    end
                                end
                            end
                        end
                        return text
                    else
                        return langs[msg.lang].require_mod
                    end
                end
                if matches[1]:lower() == 'restrict' then
                    if msg.from.is_mod then
                        mystat('/restrict')
                        local restrictions = clone_table(default_restrictions)
                        local text = ''
                        if msg.reply then
                            if matches[2] then
                                if matches[2]:lower() == 'from' then
                                    if msg.reply_to_message.forward then
                                        if msg.reply_to_message.forward_from then
                                            if matches[3] then
                                                restrictions = adjustRestrictions(matches[3]:lower())
                                            end
                                            return restrictUser(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id, restrictions)
                                        else
                                            return langs[msg.lang].cantDoThisToChat
                                        end
                                    else
                                        return langs[msg.lang].errorNoForward
                                    end
                                else
                                    if matches[2] then
                                        restrictions = adjustRestrictions(matches[2]:lower())
                                    end
                                    return restrictUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id, restrictions)
                                end
                            else
                                if matches[2] then
                                    restrictions = adjustRestrictions(matches[2]:lower())
                                end
                                return restrictUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id, restrictions)
                            end
                        elseif matches[2] and matches[2] ~= '' then
                            if msg.entities then
                                for k, v in pairs(msg.entities) do
                                    -- check if there's a text_mention
                                    if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                        if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                            if matches[3] then
                                                restrictions = adjustRestrictions(matches[3]:lower())
                                            end
                                            return restrictUser(msg.from.id, msg.entities[k].user.id, msg.chat.id, restrictions)
                                        end
                                    end
                                end
                            end
                            matches[2] = tostring(matches[2]):gsub(' ', '')
                            local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                            if obj_user then
                                if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                    if string.match(matches[2], '^%d+$') then
                                        if matches[3] then
                                            restrictions = adjustRestrictions(matches[3]:lower())
                                        end
                                        return restrictUser(msg.from.id, obj_user.id, msg.chat.id, restrictions)
                                    else
                                        if matches[3] then
                                            restrictions = adjustRestrictions(matches[3]:lower())
                                        end
                                        return restrictUser(msg.from.id, obj_user.id, msg.chat.id, restrictions)
                                    end
                                end
                            else
                                return langs[msg.lang].noObject
                            end
                        end
                        return text
                    else
                        return langs[msg.lang].require_mod
                    end
                end
                if matches[1]:lower() == 'unrestrict' then
                    if msg.from.is_mod then
                        mystat('/unrestrict')
                        if msg.reply then
                            if matches[2] then
                                if matches[2]:lower() == 'from' then
                                    if msg.reply_to_message.forward then
                                        if msg.reply_to_message.forward_from then
                                            return unrestrictUser(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id)
                                        else
                                            return langs[msg.lang].cantDoThisToChat
                                        end
                                    else
                                        return langs[msg.lang].errorNoForward
                                    end
                                else
                                    return unrestrictUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id)
                                end
                            else
                                return unrestrictUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id)
                            end
                        elseif matches[2] and matches[2] ~= '' then
                            if msg.entities then
                                for k, v in pairs(msg.entities) do
                                    -- check if there's a text_mention
                                    if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                        if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                            return unrestrictUser(msg.from.id, msg.entities[k].user.id, msg.chat.id)
                                        end
                                    end
                                end
                            end
                            matches[2] = tostring(matches[2]):gsub(' ', '')
                            if string.match(matches[2], '^%d+$') then
                                return unrestrictUser(msg.from.id, matches[2], msg.chat.id)
                            else
                                local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                                if obj_user then
                                    if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                        return unrestrictUser(msg.from.id, obj_user.id, msg.chat.id)
                                    else
                                        return langs[msg.lang].cantDoThisToChat
                                    end
                                else
                                    return langs[msg.lang].noObject
                                end
                            end
                        end
                        return
                    else
                        return langs[msg.lang].require_mod
                    end
                end
                if matches[1]:lower() == 'restrictions' then
                    mystat('/restrictions')
                    local chat_name = ''
                    if data[tostring(msg.chat.id)] then
                        chat_name = data[tostring(msg.chat.id)].name or ''
                    end
                    restrictionsTable[tostring(msg.chat.id)] = restrictionsTable[tostring(msg.chat.id)] or { }
                    if msg.from.is_mod then
                        if msg.reply then
                            if matches[2] then
                                if matches[2]:lower() == 'from' then
                                    if msg.reply_to_message.forward then
                                        if msg.reply_to_message.forward_from then
                                            if sendKeyboard(msg.from.id, string.gsub(string.gsub(langs[msg.lang].restrictionsOf, 'Y', '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name), 'X', tostring('(#user' .. tostring(msg.reply_to_message.forward_from.id) .. ') ' .. msg.reply_to_message.forward_from.first_name .. ' ' ..(msg.reply_to_message.forward_from.last_name or ''))) .. '\n' .. langs[msg.lang].restrictionsIntro .. langs[msg.lang].faq[16], keyboard_restrictions_list(msg.chat.id, msg.reply_to_message.forward_from.id)) then
                                                restrictionsTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.forward_from.id)] = userRestrictions(msg.chat.id, msg.reply_to_message.forward_from.id)
                                                if msg.chat.type ~= 'private' then
                                                    local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendRestrictionsPvt, 'html'))
                                                    io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                    return
                                                end
                                            else
                                                return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                            end
                                        else
                                            return langs[msg.lang].cantDoThisToChat
                                        end
                                    else
                                        return langs[msg.lang].errorNoForward
                                    end
                                end
                            else
                                if sendKeyboard(msg.from.id, string.gsub(string.gsub(langs[msg.lang].restrictionsOf, 'Y', '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name), 'X', tostring('(#user' .. tostring(msg.reply_to_message.from.id) .. ') ' .. msg.reply_to_message.from.first_name .. ' ' ..(msg.reply_to_message.from.last_name or ''))) .. '\n' .. langs[msg.lang].restrictionsIntro .. langs[msg.lang].faq[16], keyboard_restrictions_list(msg.chat.id, msg.reply_to_message.from.id)) then
                                    restrictionsTable[tostring(msg.chat.id)][tostring(msg.reply_to_message.from.id)] = userRestrictions(msg.chat.id, msg.reply_to_message.from.id)
                                    if msg.chat.type ~= 'private' then
                                        local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendRestrictionsPvt, 'html'))
                                        io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                        return
                                    end
                                else
                                    return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                end
                                return
                            end
                        elseif matches[2] and matches[2] ~= '' then
                            if msg.entities then
                                for k, v in pairs(msg.entities) do
                                    -- check if there's a text_mention
                                    if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                        if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                            if sendKeyboard(msg.from.id, string.gsub(string.gsub(langs[msg.lang].restrictionsOf, 'Y', '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name), 'X', tostring('(#user' .. tostring(msg.entities[k].user.id) .. ') ' .. msg.entities[k].user.first_name .. ' ' ..(msg.entities[k].user.last_name or ''))) .. '\n' .. langs[msg.lang].restrictionsIntro .. langs[msg.lang].faq[16], keyboard_restrictions_list(msg.chat.id, msg.entities[k].user.id)) then
                                                restrictionsTable[tostring(msg.chat.id)][tostring(msg.entities[k].user.id)] = userRestrictions(msg.chat.id, msg.entities[k].user.id)
                                                if msg.chat.type ~= 'private' then
                                                    local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendRestrictionsPvt, 'html'))
                                                    io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                    return
                                                end
                                            else
                                                return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                            end
                                        end
                                    end
                                end
                            end
                            matches[2] = tostring(matches[2]):gsub(' ', '')
                            if string.match(matches[2], '^%d+$') then
                                local obj_user = getChat(matches[2])
                                if type(obj_user) == 'table' then
                                    if obj_user then
                                        if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                            if sendKeyboard(msg.from.id, string.gsub(string.gsub(langs[msg.lang].restrictionsOf, 'Y', '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name), 'X', tostring('(#user' .. tostring(obj_user.id) .. ') ' .. obj_user.first_name .. ' ' ..(obj_user.last_name or ''))) .. '\n' .. langs[msg.lang].restrictionsIntro .. langs[msg.lang].faq[16], keyboard_restrictions_list(msg.chat.id, obj_user.id)) then
                                                restrictionsTable[tostring(msg.chat.id)][tostring(obj_user.id)] = userRestrictions(msg.chat.id, obj_user.id)
                                                if msg.chat.type ~= 'private' then
                                                    local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendRestrictionsPvt, 'html'))
                                                    io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                    return
                                                end
                                            else
                                                return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                            end
                                        end
                                    else
                                        return langs[msg.lang].noObject
                                    end
                                end
                            else
                                local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                                if obj_user then
                                    if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                        if sendKeyboard(msg.from.id, string.gsub(string.gsub(langs[msg.lang].restrictionsOf, 'Y', '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name), 'X', tostring('(#user' .. tostring(obj_user.id) .. ') ' .. obj_user.first_name .. ' ' ..(obj_user.last_name or ''))) .. '\n' .. langs[msg.lang].restrictionsIntro .. langs[msg.lang].faq[16], keyboard_restrictions_list(msg.chat.id, obj_user.id)) then
                                            restrictionsTable[tostring(msg.chat.id)][tostring(obj_user.id)] = userRestrictions(msg.chat.id, obj_user.id)
                                            if msg.chat.type ~= 'private' then
                                                local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendRestrictionsPvt, 'html'))
                                                io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                return
                                            end
                                        else
                                            return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                        end
                                    end
                                else
                                    return langs[msg.lang].noObject
                                end
                            end
                        end
                        return
                    else
                        return langs[msg.lang].require_mod
                    end
                end
                if matches[1]:lower() == 'textualrestrictions' then
                    mystat('/restrictions')
                    if msg.from.is_mod then
                        if msg.reply then
                            if matches[2] then
                                if matches[2]:lower() == 'from' then
                                    if msg.reply_to_message.forward then
                                        if msg.reply_to_message.forward_from then
                                            return showRestrictions(msg.chat.id, msg.reply_to_message.forward_from.id, msg.lang)
                                        else
                                            return langs[msg.lang].cantDoThisToChat
                                        end
                                    else
                                        return langs[msg.lang].errorNoForward
                                    end
                                else
                                    return showRestrictions(msg.chat.id, msg.reply_to_message.from.id, msg.lang)
                                end
                            else
                                return showRestrictions(msg.chat.id, msg.reply_to_message.from.id, msg.lang)
                            end
                        elseif matches[2] and matches[2] ~= '' then
                            if msg.entities then
                                for k, v in pairs(msg.entities) do
                                    -- check if there's a text_mention
                                    if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                        if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                            return showRestrictions(msg.chat.id, msg.entities[k].user.id, msg.lang)
                                        end
                                    end
                                end
                            end
                            matches[2] = tostring(matches[2]):gsub(' ', '')
                            if string.match(matches[2], '^%d+$') then
                                local obj_user = getChat(matches[2])
                                if obj_user then
                                    if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                        return showRestrictions(msg.chat.id, obj_user.id, msg.lang)
                                    end
                                else
                                    return langs[msg.lang].noObject
                                end
                            else
                                local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                                if obj_user then
                                    if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                        return showRestrictions(msg.chat.id, obj_user.id, msg.lang)
                                    end
                                else
                                    return langs[msg.lang].noObject
                                end
                            end
                        end
                        return
                    else
                        return langs[msg.lang].require_mod
                    end
                end
            end
            if matches[1]:lower() == 'kick' then
                if msg.from.is_mod then
                    mystat('/kick')
                    if msg.reply then
                        if matches[2] then
                            if matches[2]:lower() == 'from' then
                                if msg.reply_to_message.forward then
                                    if msg.reply_to_message.forward_from then
                                        return kickUser(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id, matches[3] or '')
                                    else
                                        return langs[msg.lang].cantDoThisToChat
                                    end
                                else
                                    return langs[msg.lang].errorNoForward
                                end
                            else
                                return kickUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                            end
                        else
                            if msg.reply_to_message.service then
                                if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                                    local text = kickUser(msg.from.id, msg.reply_to_message.adder.id, msg.chat.id) .. '\n'
                                    for k, v in pairs(msg.reply_to_message.added) do
                                        text = text .. kickUser(msg.from.id, v.id, msg.chat.id) .. '\n'
                                    end
                                    return text ..(matches[2] or '') .. ' ' ..(matches[3] or '')
                                elseif msg.reply_to_message.service_type == 'chat_del_user' then
                                    return kickUser(msg.from.id, msg.reply_to_message.removed.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                else
                                    return kickUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                end
                            else
                                return kickUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                            end
                        end
                    elseif matches[2] and matches[2] ~= '' then
                        if msg.entities then
                            for k, v in pairs(msg.entities) do
                                -- check if there's a text_mention
                                if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                    if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                        return kickUser(msg.from.id, msg.entities[k].user.id, msg.chat.id, matches[3] or '')
                                    end
                                end
                            end
                        end
                        matches[2] = tostring(matches[2]):gsub(' ', '')
                        if string.match(matches[2], '^%d+$') then
                            return kickUser(msg.from.id, matches[2], msg.chat.id, matches[3] or '')
                        else
                            local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                            if obj_user then
                                if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                    return kickUser(msg.from.id, obj_user.id, msg.chat.id, matches[3] or '')
                                end
                            else
                                return langs[msg.lang].noObject
                            end
                        end
                    end
                    return
                else
                    return langs[msg.lang].require_mod
                end
            end
            --[[if matches[1]:lower() == 'kickrandom' then
                if msg.from.is_mod then
                    return langs[msg.lang].useAISasha
                    mystat('/kickrandom')
                    local kickable = false
                    local id
                    local participants = getChatParticipants(msg.chat.id)
                    local unlocker = 0
                    while not kickable do
                        if unlocker == 100 then
                            return langs[msg.lang].badLuck
                        end
                        id = participants[math.random(#participants)].user.id
                        print(id)
                        if tonumber(id) ~= tonumber(bot.id) and not is_mod2(id, msg.chat.id, true) and not isWhitelisted(msg.chat.id, id) then
                            kickable = true
                            kickUser(msg.from.id, id, msg.chat.id)
                        else
                            print('403')
                            unlocker = unlocker + 1
                        end
                    end
                    return id .. langs[msg.lang].kicked
                else
                    return langs[msg.lang].require_mod
                end
            end
            if matches[1]:lower() == 'kickdeleted' then
                if msg.from.is_mod then
                    return langs[msg.lang].useAISasha
                    mystat('/kickdeleted')
                    local kicked = 0
                    local participants = getChatParticipants(msg.chat.id)
                    for k, v in pairs(participants) do
                        if v.user then
                            v = v.user
                            if not v.first_name then
                                if v.id then
                                    kickUser(msg.from.id, v.id, msg.chat.id)
                                    kicked = kicked + 1
                                end
                            end
                        end
                    end
                    return langs[msg.lang].massacre:gsub('X', kicked)
                else
                    return langs[msg.lang].require_mod
                end
            end
            if matches[1]:lower() == 'kickinactive' then
                if msg.from.is_owner then
                    return langs[msg.lang].kickinactiveWarning
                    mystat('/kickinactive')
                    local num = matches[2] or 0
                    return kickinactive(msg.from.id, msg.chat.id, tonumber(num))
                else
                    return langs[msg.lang].require_owner
                end
            end
            if matches[1]:lower() == 'kicknouser' then
                if msg.from.is_owner then
                    return langs[msg.lang].useAISasha
                    mystat('/kicknouser')
                    local kicked = 0
                    local participants = getChatParticipants(msg.chat.id)
                    for k, v in pairs(participants) do
                        if v.user then
                            v = v.user
                            if not v.username then
                                kickUser(msg.from.id, v.id, msg.chat.id)
                                kicked = kicked + 1
                            end
                        end
                    end
                    return langs[msg.lang].massacre:gsub('X', kicked)
                else
                    return langs[msg.lang].require_owner
                end
            end]]
            if matches[1]:lower() == 'banlist' and not matches[2] then
                if msg.from.is_mod then
                    mystat('/banlist')
                    return banList(msg.chat.id)
                else
                    return langs[msg.lang].require_mod
                end
            end
            if matches[1]:lower() == 'countbanlist' and not matches[2] then
                if msg.from.is_mod then
                    mystat('/countbanlist')
                    local list = redis_get_something('banned:' .. msg.chat.id) or { }
                    local i = 0
                    for k, v in pairs(list) do
                        i = i + 1
                    end
                    return i
                else
                    return langs[msg.lang].require_mod
                end
            end
            if tostring(msg.chat.id):starts('-100') then
                if matches[1]:lower() == 'tempban' then
                    if msg.from.is_mod then
                        mystat('/ban')
                        local chat_name = ''
                        if data[tostring(msg.chat.id)] then
                            chat_name = data[tostring(msg.chat.id)].name or ''
                        end
                        if msg.reply then
                            if matches[2] then
                                if matches[2]:lower() == 'from' then
                                    if msg.reply_to_message.forward then
                                        if msg.reply_to_message.forward_from then
                                            local time = 0
                                            if matches[3] and matches[4] and matches[5] and matches[6] and matches[7] then
                                                time = dateToUnix(matches[7], matches[6], matches[5], matches[4], matches[3])
                                                return banUser(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id, matches[8] or '', time)
                                            else
                                                if compare_ranks(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id) then
                                                    if sendKeyboard(msg.from.id, '(#user' .. tostring(msg.reply_to_message.forward_from.id) .. ') ' ..(database[tostring(msg.reply_to_message.forward_from.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPBAN', msg.chat.id, msg.reply_to_message.forward_from.id)) then
                                                        if msg.chat.type ~= 'private' then
                                                            local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                            io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                            return
                                                        end
                                                    else
                                                        return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                                    end
                                                else
                                                    return langs[msg.lang].require_rank
                                                end
                                            end
                                        else
                                            return langs[msg.lang].cantDoThisToChat
                                        end
                                    else
                                        return langs[msg.lang].errorNoForward
                                    end
                                else
                                    local time = 0
                                    if matches[2] and matches[3] and matches[4] and matches[5] and matches[6] then
                                        time = dateToUnix(matches[6], matches[5], matches[4], matches[3], matches[2])
                                        return banUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[7] or '') .. ' ' ..(matches[8] or ''), time)
                                    else
                                        if compare_ranks(msg.from.id, msg.reply_to_message.from.id, msg.chat.id) then
                                            if sendKeyboard(msg.from.id, '(#user' .. tostring(msg.reply_to_message.from.id) .. ') ' ..(database[tostring(msg.reply_to_message.from.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPBAN', msg.chat.id, msg.reply_to_message.from.id)) then
                                                if msg.chat.type ~= 'private' then
                                                    local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                    io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                    return
                                                end
                                            else
                                                return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                            end
                                        else
                                            return langs[msg.lang].require_rank
                                        end
                                    end
                                end
                            else
                                if msg.reply_to_message.service then
                                    local time = 0
                                    if matches[2] and matches[3] and matches[4] and matches[5] and matches[6] then
                                        time = dateToUnix(matches[6], matches[5], matches[4], matches[3], matches[2])
                                        if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                                            local text = banUser(msg.from.id, msg.reply_to_message.adder.id, msg.chat.id, '', time) .. '\n'
                                            for k, v in pairs(msg.reply_to_message.added) do
                                                text = text .. banUser(msg.from.id, v.id, msg.chat.id, '', time) .. '\n'
                                            end
                                            return text ..(matches[7] or '') .. ' ' ..(matches[8] or '')
                                        elseif msg.reply_to_message.service_type == 'chat_del_user' then
                                            return banUser(msg.from.id, msg.reply_to_message.removed.id, msg.chat.id,(matches[7] or '') .. ' ' ..(matches[8] or ''), time)
                                        else
                                            return banUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[7] or '') .. ' ' ..(matches[8] or ''), time)
                                        end
                                    else
                                        if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                                            local text = ''
                                            if compare_ranks(msg.from.id, msg.reply_to_message.adder.id, msg.chat.id) then
                                                if sendKeyboard(msg.from.id, '(#user' .. tostring(msg.reply_to_message.adder.id) .. ') ' ..(database[tostring(msg.reply_to_message.adder.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPBAN', msg.chat.id, msg.reply_to_message.adder.id)) then
                                                    if msg.chat.type ~= 'private' then
                                                        text = text .. langs[msg.lang].sendTimeKeyboardPvt .. '\n'
                                                    end
                                                else
                                                    return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                                end
                                            else
                                                text = text .. langs[msg.lang].require_rank .. '\n'
                                            end
                                            for k, v in pairs(msg.reply_to_message.added) do
                                                if compare_ranks(msg.from.id, v.id, msg.chat.id) then
                                                    if sendKeyboard(msg.from.id, '(#user' .. tostring(v.id) .. ') ' ..(database[tostring(v.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPBAN', msg.chat.id, v.id)) then
                                                        if msg.chat.type ~= 'private' then
                                                            text = text .. langs[msg.lang].sendTimeKeyboardPvt .. '\n'
                                                        end
                                                    else
                                                        return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                                    end
                                                else
                                                    text = text .. langs[msg.lang].require_rank .. '\n'
                                                end
                                            end
                                            if msg.chat.type ~= 'private' then
                                                local message_id = getMessageId(sendReply(msg, text))
                                                io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                return
                                            end
                                            return sendReply(msg, text, 'html')
                                        elseif msg.reply_to_message.service_type == 'chat_del_user' then
                                            if compare_ranks(msg.from.id, msg.reply_to_message.removed.id, msg.chat.id) then
                                                if sendKeyboard(msg.from.id, '(#user' .. tostring(msg.reply_to_message.removed.id) .. ') ' ..(database[tostring(msg.reply_to_message.removed.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPBAN', msg.chat.id, msg.reply_to_message.removed.id)) then
                                                    if msg.chat.type ~= 'private' then
                                                        local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                        io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')

                                                        return
                                                    end
                                                else
                                                    return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                                end
                                            else
                                                return langs[msg.lang].require_rank
                                            end
                                        else
                                            if compare_ranks(msg.from.id, msg.reply_to_message.from.id, msg.chat.id) then
                                                if sendKeyboard(msg.from.id, '(#user' .. tostring(msg.reply_to_message.from.id) .. ') ' ..(database[tostring(msg.reply_to_message.from.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPBAN', msg.chat.id, msg.reply_to_message.from.id)) then
                                                    if msg.chat.type ~= 'private' then
                                                        local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                        io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                        return
                                                    end
                                                else
                                                    return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                                end
                                            else
                                                return langs[msg.lang].require_rank
                                            end
                                        end
                                    end
                                else
                                    local time = 0
                                    if matches[2] and matches[3] and matches[4] and matches[5] and matches[6] then
                                        time = dateToUnix(matches[6], matches[5], matches[4], matches[3], matches[2])
                                        return banUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[7] or '') .. ' ' ..(matches[8] or ''), time)
                                    else
                                        if compare_ranks(msg.from.id, msg.reply_to_message.from.id, msg.chat.id) then
                                            if sendKeyboard(msg.from.id, '(#user' .. tostring(msg.reply_to_message.from.id) .. ') ' ..(database[tostring(msg.reply_to_message.from.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPBAN', msg.chat.id, msg.reply_to_message.from.id)) then
                                                if msg.chat.type ~= 'private' then
                                                    local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                    io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                    return
                                                end
                                            else
                                                return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                            end
                                        else
                                            return langs[msg.lang].require_rank
                                        end
                                    end
                                end
                            end
                        elseif matches[2] and matches[2] ~= '' then
                            local time = 0
                            if matches[3] and matches[4] and matches[5] and matches[6] and matches[7] then
                                time = dateToUnix(matches[7], matches[6], matches[5], matches[4], matches[3])
                                if msg.entities then
                                    for k, v in pairs(msg.entities) do
                                        -- check if there's a text_mention
                                        if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                            if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                                return banUser(msg.from.id, msg.entities[k].user.id, msg.chat.id, matches[8] or '', time)
                                            end
                                        end
                                    end
                                end
                                matches[2] = tostring(matches[2]):gsub(' ', '')
                                if string.match(matches[2], '^%d+$') then
                                    return banUser(msg.from.id, matches[2], msg.chat.id, matches[8] or '', time)
                                else
                                    local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                                    if obj_user then
                                        if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                            return banUser(msg.from.id, obj_user.id, msg.chat.id, matches[8] or '', time)
                                        end
                                    else
                                        return langs[msg.lang].noObject
                                    end
                                end
                            else
                                if msg.entities then
                                    for k, v in pairs(msg.entities) do
                                        -- check if there's a text_mention
                                        if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                            if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                                if compare_ranks(msg.from.id, msg.entities[k].user.id, msg.chat.id) then
                                                    if sendKeyboard(msg.from.id, '(#user' .. tostring(msg.entities[k].user.id) .. ') ' ..(database[tostring(msg.entities[k].user.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPBAN', msg.chat.id, msg.entities[k].user.id)) then
                                                        if msg.chat.type ~= 'private' then
                                                            local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                            io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                            return
                                                        end
                                                    else
                                                        return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                                    end
                                                else
                                                    return langs[msg.lang].require_rank
                                                end
                                            end
                                        end
                                    end
                                end
                                matches[2] = tostring(matches[2]):gsub(' ', '')
                                if string.match(matches[2], '^%d+$') then
                                    if compare_ranks(msg.from.id, matches[2], msg.chat.id) then
                                        if sendKeyboard(msg.from.id, '(#user' .. tostring(matches[2]) .. ') ' ..(database[tostring(matches[2])]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPBAN', msg.chat.id, matches[2])) then
                                            if msg.chat.type ~= 'private' then
                                                local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                return
                                            end
                                        else
                                            return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                        end
                                    else
                                        return langs[msg.lang].require_rank
                                    end
                                else
                                    local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                                    if obj_user then
                                        if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                            if compare_ranks(msg.from.id, obj_user.id, msg.chat.id) then
                                                if sendKeyboard(msg.from.id, '(#user' .. tostring(obj_user.id) .. ') ' ..(database[tostring(obj_user.id)]['print_name'] or '') .. ' in ' .. '(#chat' .. tostring(msg.chat.id):gsub("-", "") .. ') ' .. chat_name .. langs[msg.lang].tempActionIntro, keyboard_time('banhammer', 'TEMPBAN', msg.chat.id, obj_user.id)) then
                                                    if msg.chat.type ~= 'private' then
                                                        local message_id = getMessageId(sendReply(msg, langs[msg.lang].sendTimeKeyboardPvt, 'html'))
                                                        io.popen('lua timework.lua "deletemessage" "60" "' .. msg.chat.id .. '" "' .. msg.message_id .. ',' ..(message_id or '') .. '"')
                                                        return
                                                    end
                                                else
                                                    return sendKeyboard(msg.chat.id, langs[msg.lang].cantSendPvt, { inline_keyboard = { { { text = "/start", url = bot.link } } } }, false, msg.message_id)
                                                end
                                            else
                                                return langs[msg.lang].require_rank
                                            end
                                        end
                                    else
                                        return langs[msg.lang].noObject
                                    end
                                end
                            end
                        end
                        return
                    else
                        return langs[msg.lang].require_mod
                    end
                end
            end
            if matches[1]:lower() == 'ban' then
                if msg.from.is_mod then
                    mystat('/ban')
                    if msg.reply then
                        if matches[2] then
                            if matches[2]:lower() == 'from' then
                                if msg.reply_to_message.forward then
                                    if msg.reply_to_message.forward_from then
                                        return banUser(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id, matches[3] or '')
                                    else
                                        return langs[msg.lang].cantDoThisToChat
                                    end
                                else
                                    return langs[msg.lang].errorNoForward
                                end
                            else
                                return banUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                            end
                        else
                            if msg.reply_to_message.service then
                                if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                                    local text = banUser(msg.from.id, msg.reply_to_message.adder.id, msg.chat.id) .. '\n'
                                    for k, v in pairs(msg.reply_to_message.added) do
                                        text = text .. banUser(msg.from.id, v.id, msg.chat.id) .. '\n'
                                    end
                                    return text ..(matches[2] or '') .. ' ' ..(matches[3] or '')
                                elseif msg.reply_to_message.service_type == 'chat_del_user' then
                                    return banUser(msg.from.id, msg.reply_to_message.removed.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                else
                                    return banUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                end
                            else
                                return banUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                            end
                        end
                    elseif matches[2] and matches[2] ~= '' then
                        if msg.entities then
                            for k, v in pairs(msg.entities) do
                                -- check if there's a text_mention
                                if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                    if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                        return banUser(msg.from.id, msg.entities[k].user.id, msg.chat.id, matches[3] or '')
                                    end
                                end
                            end
                        end
                        matches[2] = tostring(matches[2]):gsub(' ', '')
                        if string.match(matches[2], '^%d+$') then
                            return banUser(msg.from.id, matches[2], msg.chat.id, matches[3] or '')
                        else
                            local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                            if obj_user then
                                if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                    return banUser(msg.from.id, obj_user.id, msg.chat.id, matches[3] or '')
                                end
                            else
                                return langs[msg.lang].noObject
                            end
                        end
                    end
                    return
                else
                    return langs[msg.lang].require_mod
                end
            end
            if matches[1]:lower() == 'unban' then
                if msg.from.is_mod then
                    mystat('/unban')
                    if msg.reply then
                        if matches[2] then
                            if matches[2]:lower() == 'from' then
                                if msg.reply_to_message.forward then
                                    if msg.reply_to_message.forward_from then
                                        return unbanUser(msg.from.id, msg.reply_to_message.forward_from.id, msg.chat.id, matches[3] or '')
                                    else
                                        return langs[msg.lang].cantDoThisToChat
                                    end
                                else
                                    return langs[msg.lang].errorNoForward
                                end
                            else
                                return unbanUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                            end
                        else
                            if msg.reply_to_message.service then
                                if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                                    local text = unbanUser(msg.from.id, msg.reply_to_message.adder.id, msg.chat.id) .. '\n'
                                    for k, v in pairs(msg.reply_to_message.added) do
                                        text = text .. unbanUser(msg.from.id, v.id, msg.chat.id) .. '\n'
                                    end
                                    return text ..(matches[2] or '') .. ' ' ..(matches[3] or '')
                                elseif msg.reply_to_message.service_type == 'chat_del_user' then
                                    return unbanUser(msg.from.id, msg.reply_to_message.removed.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                else
                                    return unbanUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                                end
                            else
                                return unbanUser(msg.from.id, msg.reply_to_message.from.id, msg.chat.id,(matches[2] or '') .. ' ' ..(matches[3] or ''))
                            end
                        end
                    elseif matches[2] and matches[2] ~= '' then
                        if msg.entities then
                            for k, v in pairs(msg.entities) do
                                -- check if there's a text_mention
                                if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                    if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                        return unbanUser(msg.from.id, msg.entities[k].user.id, msg.chat.id, matches[3] or '')
                                    end
                                end
                            end
                        end
                        matches[2] = tostring(matches[2]):gsub(' ', '')
                        if string.match(matches[2], '^%d+$') then
                            return unbanUser(msg.from.id, matches[2], msg.chat.id, matches[3] or '')
                        else
                            local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                            if obj_user then
                                if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                    return unbanUser(msg.from.id, obj_user.id, msg.chat.id, matches[3] or '')
                                end
                            else
                                return langs[msg.lang].noObject
                            end
                        end
                    end
                    return
                else
                    return langs[msg.lang].require_mod
                end
            end
        end
        if matches[1]:lower() == 'gban' then
            if is_admin(msg) then
                mystat('/gban')
                if msg.reply then
                    if matches[2] then
                        if matches[2]:lower() == 'from' then
                            if msg.reply_to_message.forward then
                                if msg.reply_to_message.forward_from then
                                    return gbanUser(msg.reply_to_message.forward_from.id)
                                else
                                    return langs[msg.lang].cantDoThisToChat
                                end
                            else
                                return langs[msg.lang].errorNoForward
                            end
                        end
                    else
                        if msg.reply_to_message.service then
                            if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                                local text = gbanUser(msg.reply_to_message.adder.id) .. '\n'
                                for k, v in pairs(msg.reply_to_message.added) do
                                    text = text .. gbanUser(v.id)
                                end
                                return text
                            elseif msg.reply_to_message.service_type == 'chat_del_user' then
                                return gbanUser(msg.reply_to_message.removed.id)
                            else
                                return gbanUser(msg.reply_to_message.from.id)
                            end
                        else
                            return gbanUser(msg.reply_to_message.from.id)
                        end
                    end
                elseif matches[2] and matches[2] ~= '' then
                    if msg.entities then
                        for k, v in pairs(msg.entities) do
                            -- check if there's a text_mention
                            if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                    return gbanUser(msg.entities[k].user.id)
                                end
                            end
                        end
                    end
                    matches[2] = tostring(matches[2]):gsub(' ', '')
                    if string.match(matches[2], '^%d+$') then
                        return gbanUser(matches[2])
                    else
                        local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                        if obj_user then
                            if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                return gbanUser(obj_user.id)
                            end
                        else
                            return langs[msg.lang].noObject
                        end
                    end
                end
                return
            else
                return langs[msg.lang].require_admin
            end
        end
        if matches[1]:lower() == 'ungban' then
            if is_admin(msg) then
                mystat('/ungban')
                if msg.reply then
                    if matches[2] then
                        if matches[2]:lower() == 'from' then
                            if msg.reply_to_message.forward then
                                if msg.reply_to_message.forward_from then
                                    return ungbanUser(msg.reply_to_message.forward_from.id)
                                else
                                    return langs[msg.lang].cantDoThisToChat
                                end
                            else
                                return langs[msg.lang].errorNoForward
                            end
                        end
                    else
                        if msg.reply_to_message.service then
                            if msg.reply_to_message.service_type == 'chat_add_user' or msg.reply_to_message.service_type == 'chat_add_users' then
                                local text = ungbanUser(msg.reply_to_message.adder.id) .. '\n'
                                for k, v in pairs(msg.reply_to_message.added) do
                                    text = text .. ungbanUser(v.id) .. '\n'
                                end
                                return text
                            elseif msg.reply_to_message.service_type == 'chat_del_user' then
                                return ungbanUser(msg.reply_to_message.removed.id)
                            else
                                return ungbanUser(msg.reply_to_message.from.id)
                            end
                        else
                            return ungbanUser(msg.reply_to_message.from.id)
                        end
                    end
                elseif matches[2] and matches[2] ~= '' then
                    if msg.entities then
                        for k, v in pairs(msg.entities) do
                            -- check if there's a text_mention
                            if msg.entities[k].type == 'text_mention' and msg.entities[k].user then
                                if ((string.find(msg.text, matches[2]) or 0) -1) == msg.entities[k].offset then
                                    return ungbanUser(msg.entities[k].user.id)
                                end
                            end
                        end
                    end
                    matches[2] = tostring(matches[2]):gsub(' ', '')
                    if string.match(matches[2], '^%d+$') then
                        return ungbanUser(matches[2])
                    else
                        local obj_user = getChat(string.match(matches[2], '^[^%s]+') or '')
                        if obj_user then
                            if obj_user.type == 'bot' or obj_user.type == 'private' or obj_user.type == 'user' then
                                return ungbanUser(obj_user.id)
                            end
                        else
                            return langs[msg.lang].noObject
                        end
                    end
                end
                return
            else
                return langs[msg.lang].require_admin
            end
        end
        if matches[1]:lower() == 'banlist' and matches[2] then
            if is_admin(msg) then
                mystat('/banlist <group_id>')
                return banList(matches[2])
            else
                return langs[msg.lang].require_admin
            end
        end
        if matches[1]:lower() == 'countbanlist' and matches[2] then
            if is_admin(msg) then
                mystat('/countbanlist <group_id>')
                local list = redis_get_something('banned:' .. matches[2]) or { }
                local i = 0
                for k, v in pairs(list) do
                    i = i + 1
                end
                return i
            else
                return langs[msg.lang].require_admin
            end
        end
        if matches[1]:lower() == 'gbanlist' then
            if is_admin(msg) then
                mystat('/gbanlist')
                local hash = 'gbanned'
                local list = redis_get_something(hash) or { }
                local gbanlist = langs[get_lang(msg.chat.id)].gbanListStart
                for k, v in pairs(list) do
                    local user_info = redis_get_something('user:' .. v)
                    if user_info and user_info.print_name then
                        local print_name = string.gsub(user_info.print_name, "_", " ")
                        local print_name = string.gsub(print_name, "?", "")
                        gbanlist = gbanlist .. k .. " - " .. print_name .. " [" .. v .. "]\n"
                    else
                        gbanlist = gbanlist .. k .. " - " .. v .. "\n"
                    end
                end
                return gbanlist
            else
                return langs[msg.lang].require_admin
            end
        end
        if matches[1]:lower() == 'countgbanlist' then
            if is_admin(msg) then
                mystat('/countgbanlist')
                local list = redis_get_something('gbanned') or { }
                local i = 0
                for k, v in pairs(list) do
                    i = i + 1
                end
                return i
            else
                return langs[msg.lang].require_admin
            end
        end
    end
end

local function pre_process(msg)
    if msg then
        -- SERVICE MESSAGE
        if msg.service then
            if msg.service_type then
                -- Check if banned users joins chat
                if msg.service_type == 'chat_add_user' or msg.service_type == 'chat_add_users' then
                    local text = ''
                    local inviteFlood = false
                    local counter = 0
                    for k, v in pairs(msg.added) do
                        counter = counter + 1
                    end
                    if counter >= 5 then
                        if not is_owner(msg) then
                            inviteFlood = true
                            if not globalCronTable.punishedTable[tostring(msg.chat.id)][tostring(msg.from.id)] then
                                text = text .. banUser(bot.id, msg.from.id, msg.chat.id, langs[msg.lang].reasonInviteFlood) .. '\n'
                            end
                            text = text .. gbanUser(msg.from.id) .. '\n'
                        end
                    end
                    for k, v in pairs(msg.added) do
                        print('Checking invited user ' .. v.id)
                        if inviteFlood then
                            text = text .. banUser(bot.id, v.id, msg.chat.id, langs[msg.lang].reasonInviteFlood) .. '\n'
                        else
                            if isGbanned(v.id) and data[tostring(msg.chat.id)].settings.locks.gbanned and not(is_mod2(v.id, msg.chat.id, true) or isWhitelistedGban(msg.chat.id, v.id)) and not globalCronTable.punishedTable[tostring(msg.chat.id)][tostring(v.id)] then
                                flag = true
                                -- if gbanned and lockgbanned and (not mod neither whitelisted) and not yet punished for something
                                print('User is gbanned!')
                                local txt = punishmentAction(bot.id, v.id, msg.chat.id, data[tostring(msg.chat.id)].settings.locks.gbanned, langs[msg.lang].reasonGbannedUser)
                                if txt ~= '' then
                                    local banhash = 'addedbanuser:' .. msg.chat.id .. ':' .. msg.from.id
                                    redis_incr(banhash)
                                    savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] added a [g]banned user > " .. v.id)
                                    savelog(msg.chat.id, msg.from.print_name .. " [" .. v.id .. "] is gbanned! punishment = " .. tostring(data[tostring(msg.chat.id)].settings.locks.gbanned))
                                    text = text .. txt
                                end
                            elseif isBanned(v.id, msg.chat.id) and not is_mod2(v.id, msg.chat.id, true) and not globalCronTable.punishedTable[tostring(msg.chat.id)][tostring(v.id)] then
                                -- if banned and not mod and not yet punished for something
                                print('User is banned!')
                                local banhash = 'addedbanuser:' .. msg.chat.id .. ':' .. msg.from.id
                                redis_incr(banhash)
                                savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] added a banned user > " .. v.id)
                                savelog(msg.chat.id, msg.from.print_name .. " [" .. v.id .. "] is banned!")
                                text = text .. banUser(bot.id, v.id, msg.chat.id, langs[msg.lang].reasonBannedUser)
                            end
                        end
                    end
                    local banhash = 'addedbanuser:' .. msg.chat.id .. ':' .. msg.from.id
                    local banaddredis = redis_get_something(banhash)
                    if banaddredis and not msg.from.is_owner then
                        if tonumber(banaddredis) >= 8 then
                            text = text .. banUser(bot.id, msg.from.id, msg.chat.id, langs[msg.lang].reasonInviteBanned) .. '\n'
                            -- Ban user who adds ban ppl more than 7 times
                            local banhash = 'addedbanuser:' .. msg.chat.id .. ':' .. msg.from.id
                            redis_set_something(banhash, 0)
                            -- Reset the Counter
                        elseif tonumber(banaddredis) >= 4 then
                            text = text .. kickUser(bot.id, msg.from.id, msg.chat.id, langs[msg.lang].reasonInviteBanned) .. '\n'
                            -- Kick user who adds ban ppl more than 3 times
                        end
                    end
                    if text ~= '' then
                        sendMessage(msg.chat.id, text)
                    end
                end
                -- Check if banned user joins chat by link
                if msg.service_type == 'chat_add_user_link' then
                    print('Checking invited user ' .. msg.from.id)
                    if isGbanned(msg.from.id) and data[tostring(msg.chat.id)].settings.locks.gbanned and not(msg.from.is_mod or isWhitelistedGban(msg.chat.id, msg.from.id)) and not globalCronTable.punishedTable[tostring(msg.chat.id)][tostring(msg.from.id)] then
                        -- if gbanned and lockgbanned and (not mod neither whitelisted) and not yet punished for something
                        print('User is gbanned!')
                        local text = punishmentAction(bot.id, msg.from.id, msg.chat.id, data[tostring(msg.chat.id)].settings.locks.gbanned, langs[msg.lang].reasonGbannedUser)
                        if text ~= '' then
                            savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] is gbanned! punishment = " .. tostring(data[tostring(msg.chat.id)].settings.locks.gbanned))
                            local message_id = getMessageId(sendKeyboard(msg.chat.id, text, keyboard_whitelist_gbanned(msg.chat.id, msg.from.id)))
                            if not data[tostring(msg.chat.id)].settings.groupnotices then
                                io.popen('lua timework.lua "deletemessage" "300" "' .. msg.chat.id .. '" "' ..(message_id or '') .. '"')
                            end
                            return nil
                        end
                        return msg
                    elseif isBanned(msg.from.id, msg.chat.id) and not msg.from.is_mod and not globalCronTable.punishedTable[tostring(msg.chat.id)][tostring(msg.from.id)] then
                        -- if banned and not mod and not yet punished for something
                        print('User is banned!')
                        savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] is banned!")
                        sendMessage(msg.chat.id, banUser(bot.id, msg.from.id, msg.chat.id, langs[msg.lang].reasonBannedUser))
                        return nil
                    end
                end
            end
        end
        -- banned user is talking !
        if msg.chat.type == 'group' or msg.chat.type == 'supergroup' then
            if isGbanned(msg.from.id) and data[tostring(msg.chat.id)].settings.locks.gbanned and not(msg.from.is_mod or isWhitelistedGban(msg.chat.id, msg.from.id)) and not globalCronTable.punishedTable[tostring(msg.chat.id)][tostring(msg.from.id)] then
                -- if gbanned and lockgbanned and (not mod neither whitelisted) and not yet punished for something
                print('User is gbanned!')
                local text = punishmentAction(bot.id, msg.from.id, msg.chat.id, data[tostring(msg.chat.id)].settings.locks.gbanned, langs[msg.lang].reasonGbannedUser)
                if text ~= '' then
                    --[[if string.match(text, langs[msg.lang].errors[1]) or string.match(text, langs[msg.lang].errors[2]) or string.match(text, langs[msg.lang].errors[3]) or string.match(text, langs[msg.lang].errors[4]) then
                        if cronTable.kickBanErrors[tostring(chat_id)] then
                            cronTable.kickBanErrors[tostring(chat_id)] = text
                            sendMessage(msg.chat.id, text)
                        end
                    end]]
                    savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] gbanned user is talking! punishment = " .. tostring(data[tostring(msg.chat.id)].settings.locks.gbanned))
                    local message_id = getMessageId(sendKeyboard(msg.chat.id, text, keyboard_whitelist_gbanned(msg.chat.id, msg.from.id)))
                    if not data[tostring(msg.chat.id)].settings.groupnotices then
                        io.popen('lua timework.lua "deletemessage" "300" "' .. msg.chat.id .. '" "' ..(message_id or '') .. '"')
                    end
                    return nil
                end
                return msg
            elseif isBanned(msg.from.id, msg.chat.id) and not msg.from.is_mod and not globalCronTable.punishedTable[tostring(msg.chat.id)][tostring(msg.from.id)] then
                -- if banned and not mod and not yet punished for something
                print('User is banned!')
                savelog(msg.chat.id, msg.from.print_name .. " [" .. msg.from.id .. "] banned user is talking!")
                sendMessage(msg.chat.id, banUser(bot.id, msg.from.id, msg.chat.id, langs[msg.lang].reasonBannedUser))
                return nil
            end
        end
        return msg
    end
end

local function cron()
    -- clear those tables on the top of the plugin
    cronTable = {
        kickBanErrors = { },
    }
end

return {
    description = "BANHAMMER",
    cron = cron,
    patterns =
    {
        "^(###cbbanhammer)(DELETE)(%u)$",
        "^(###cbbanhammer)(DELETE)$",
        "^(###cbbanhammer)(WHITELISTGBAN)(%d+)(%-%d+)$",
        "^(###cbbanhammer)(BACK)(%d+)(%-%d+)(%u)$",
        "^(###cbbanhammer)(BACK)(%d+)(%-%d+)$",
        "^(###cbbanhammer)(RESTRICTIONSDONE)(%d+)(%-%d+)(%u)$",
        "^(###cbbanhammer)(RESTRICTIONSDONE)(%d+)(%-%d+)$",
        "^(###cbbanhammer)(RESTRICT)(%d+)(.*)(%-%d+)(%u)$",
        "^(###cbbanhammer)(RESTRICT)(%d+)(.*)(%-%d+)$",
        "^(###cbbanhammer)(UNRESTRICT)(%d+)(.*)(%-%d+)(%u)$",
        "^(###cbbanhammer)(UNRESTRICT)(%d+)(.*)(%-%d+)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(BACK)(%d+)(%-%d+)(%u)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(SECONDS)([%+%-]?%d+)(%-%d+)%$(%d+)(%u)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(MINUTES)([%+%-]?%d+)(%-%d+)%$(%d+)(%u)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(HOURS)([%+%-]?%d+)(%-%d+)%$(%d+)(%u)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(DAYS)([%+%-]?%d+)(%-%d+)%$(%d+)(%u)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(WEEKS)([%+%-]?%d+)(%-%d+)%$(%d+)(%u)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(DONE)(%d+)(%-%d+)(%u)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(BACK)(%d+)(%-%d+)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(SECONDS)([%+%-]?%d+)(%-%d+)%$(%d+)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(MINUTES)([%+%-]?%d+)(%-%d+)%$(%d+)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(HOURS)([%+%-]?%d+)(%-%d+)%$(%d+)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(DAYS)([%+%-]?%d+)(%-%d+)%$(%d+)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(WEEKS)([%+%-]?%d+)(%-%d+)%$(%d+)$",
        "^(###cbbanhammer)(TEMPBAN)(%d+)(DONE)(%d+)(%-%d+)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(BACK)(%d+)(%-%d+)(%u)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(SECONDS)([%+%-]?%d+)(%-%d+)%$(%d+)(%u)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(MINUTES)([%+%-]?%d+)(%-%d+)%$(%d+)(%u)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(HOURS)([%+%-]?%d+)(%-%d+)%$(%d+)(%u)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(DAYS)([%+%-]?%d+)(%-%d+)%$(%d+)(%u)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(WEEKS)([%+%-]?%d+)(%-%d+)%$(%d+)(%u)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(DONE)(%d+)(%-%d+)(%u)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(BACK)(%d+)(%-%d+)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(SECONDS)([%+%-]?%d+)(%-%d+)%$(%d+)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(MINUTES)([%+%-]?%d+)(%-%d+)%$(%d+)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(HOURS)([%+%-]?%d+)(%-%d+)%$(%d+)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(DAYS)([%+%-]?%d+)(%-%d+)%$(%d+)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(WEEKS)([%+%-]?%d+)(%-%d+)%$(%d+)$",
        "^(###cbbanhammer)(TEMPRESTRICT)(%d+)(DONE)(%d+)(%-%d+)$",

        "^[#!/]([Ii][Nn][Vv][Ii][Tt][Ee])$",
        "^[#!/]([Ii][Nn][Vv][Ii][Tt][Ee]) ([^%s]+)$",
        "^[#!/]([Ii][Nn][Vv][Ii][Tt][Ee]) (.*)$",
        "^[#!/]([Gg][Ee][Tt][Uu][Ss][Ee][Rr][Ww][Aa][Rr][Nn][Ss]) ([^%s]+)$",
        "^[#!/]([Gg][Ee][Tt][Uu][Ss][Ee][Rr][Ww][Aa][Rr][Nn][Ss])$",
        "^[#!/]([Uu][Nn][Ww][Aa][Rr][Nn][Aa][Ll][Ll]) ([^%s]+) ?(.*)$",
        "^[#!/]([Uu][Nn][Ww][Aa][Rr][Nn][Aa][Ll][Ll]) (.*)$",
        "^[#!/]([Uu][Nn][Ww][Aa][Rr][Nn][Aa][Ll][Ll])$",
        "^[#!/]([Uu][Nn][Ww][Aa][Rr][Nn]) ([^%s]+) ?(.*)$",
        "^[#!/]([Uu][Nn][Ww][Aa][Rr][Nn]) (.*)$",
        "^[#!/]([Uu][Nn][Ww][Aa][Rr][Nn])$",
        "^[#!/]([Ww][Aa][Rr][Nn]) ([^%s]+) ?(.*)$",
        "^[#!/]([Ww][Aa][Rr][Nn]) (.*)$",
        "^[#!/]([Ww][Aa][Rr][Nn])$",
        "^[#!/]([Mm][Uu][Tt][Ee][Uu][Ss][Ee][Rr]) ([^%s]+)$",
        "^[#!/]([Mm][Uu][Tt][Ee][Uu][Ss][Ee][Rr])$",
        "^[#!/]([Mm][Uu][Tt][Ee][Ll][Ii][Ss][Tt])$",
        "^[#!/]([Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt]) ([^%s]+) (.*)$",
        "^[#!/]([Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt]) (.*)$",
        "^[#!/]([Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt])$",
        "^[#!/]([Tt][Ee][Mm][Pp][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt]) ([^%s]+) (%d+) (%d+) (%d+) (%d+) (%d+) (.*)$",
        "^[#!/]([Tt][Ee][Mm][Pp][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt]) (%d+) (%d+) (%d+) (%d+) (%d+) (.*)$",
        "^[#!/]([Tt][Ee][Mm][Pp][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt]) (%d+) (%d+) (%d+) (%d+) (%d+)$",
        "^[#!/]([Tt][Ee][Mm][Pp][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt]) ([^%s]+) (.*)$",
        "^[#!/]([Tt][Ee][Mm][Pp][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt]) (.*)$",
        "^[#!/]([Tt][Ee][Mm][Pp][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt])$",
        "^[#!/]([Uu][Nn][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt]) ([^%s]+)$",
        "^[#!/]([Uu][Nn][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt])$",
        "^[#!/]([Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt][Ii][Oo][Nn][Ss]) ([^%s]+)$",
        "^[#!/]([Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt][Ii][Oo][Nn][Ss])$",
        "^[#!/]([Tt][Ee][Mm][Pp][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt][Ii][Oo][Nn][Ss]) ([^%s]+)$",
        "^[#!/]([Tt][Ee][Mm][Pp][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt][Ii][Oo][Nn][Ss])$",
        "^[#!/]([Tt][Ee][Xx][Tt][Uu][Aa][Ll][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt][Ii][Oo][Nn][Ss]) ([^%s]+)$",
        "^[#!/]([Tt][Ee][Xx][Tt][Uu][Aa][Ll][Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt][Ii][Oo][Nn][Ss])$",
        "^[#!/]([Kk][Ii][Cc][Kk][Mm][Ee])",
        "^[#!/]([Kk][Ii][Cc][Kk][Rr][Aa][Nn][Dd][Oo][Mm])$",
        "^[#!/]([Kk][Ii][Cc][Kk][Nn][Oo][Uu][Ss][Ee][Rr])$",
        "^[#!/]([Kk][Ii][Cc][Kk][Ii][Nn][Aa][Cc][Tt][Ii][Vv][Ee])$",
        "^[#!/]([Kk][Ii][Cc][Kk][Ii][Nn][Aa][Cc][Tt][Ii][Vv][Ee]) (%d+)$",
        "^[#!/]([Kk][Ii][Cc][Kk][Dd][Ee][Ll][Ee][Tt][Ee][Dd])$",
        "^[#!/]([Kk][Ii][Cc][Kk]) ([^%s]+) ?(.*)$",
        "^[#!/]([Kk][Ii][Cc][Kk]) (.*)$",
        "^[#!/]([Kk][Ii][Cc][Kk])$",
        "^[#!/]([Bb][Aa][Nn][Ll][Ii][Ss][Tt]) (%-%d+)$",
        "^[#!/]([Bb][Aa][Nn][Ll][Ii][Ss][Tt])$",
        "^[#!/]([Cc][Oo][Uu][Nn][Tt][Bb][Aa][Nn][Ll][Ii][Ss][Tt]) (%-%d+)$",
        "^[#!/]([Cc][Oo][Uu][Nn][Tt][Bb][Aa][Nn][Ll][Ii][Ss][Tt])$",
        "^[#!/]([Bb][Aa][Nn]) ([^%s]+) ?(.*)$",
        "^[#!/]([Bb][Aa][Nn]) (.*)$",
        "^[#!/]([Bb][Aa][Nn])$",
        "^[#!/]([Tt][Ee][Mm][Pp][Bb][Aa][Nn]) ([^%s]+) (%d+) (%d+) (%d+) (%d+) (%d+) ?(.*)$",
        "^[#!/]([Tt][Ee][Mm][Pp][Bb][Aa][Nn]) (%d+) (%d+) (%d+) (%d+) (%d+) (.*)$",
        "^[#!/]([Tt][Ee][Mm][Pp][Bb][Aa][Nn]) (%d+) (%d+) (%d+) (%d+) (%d+)$",
        "^[#!/]([Tt][Ee][Mm][Pp][Bb][Aa][Nn]) ([^%s]+) ?(.*)$",
        "^[#!/]([Tt][Ee][Mm][Pp][Bb][Aa][Nn]) (.*)$",
        "^[#!/]([Tt][Ee][Mm][Pp][Bb][Aa][Nn])$",
        "^[#!/]([Uu][Nn][Bb][Aa][Nn]) ([^%s]+) ?(.*)$",
        "^[#!/]([Uu][Nn][Bb][Aa][Nn]) (.*)$",
        "^[#!/]([Uu][Nn][Bb][Aa][Nn])$",
        "^[#!/]([Gg][Bb][Aa][Nn]) ([^%s]+)$",
        "^[#!/]([Gg][Bb][Aa][Nn])$",
        "^[#!/]([Uu][Nn][Gg][Bb][Aa][Nn]) ([^%s]+)$",
        "^[#!/]([Uu][Nn][Gg][Bb][Aa][Nn])$",
        "^[#!/]([Gg][Bb][Aa][Nn][Ll][Ii][Ss][Tt])$",
        "^[#!/]([Cc][Oo][Uu][Nn][Tt][Gg][Bb][Aa][Nn][Ll][Ii][Ss][Tt])$",
    },
    run = run,
    pre_process = pre_process,
    min_rank = 1,
    syntax =
    {
        "USER",
        "/kickme",
        "MOD",
        "/invite {user}",
        "/getuserwarns {user}",
        "/muteuser {user}",
        "/mutelist",
        "/warn {user} [{reason}]",
        "/unwarn {user} [{reason}]",
        "/unwarnall {user} [{reason}]",
        "/temprestrict {user} [{weeks} {days} {hours} {minutes} {seconds}] [send_messages] [send_media_messages] [send_other_messages] [add_web_page_previews]",
        "/restrict {user} [send_messages] [send_media_messages] [send_other_messages] [add_web_page_previews]",
        "/unrestrict {user}",
        "/[textual]restrictions {user}",
        "/kick {user} [{reason}]",
        "/tempban {user} [{weeks} {days} {hours} {minutes} {seconds}] [{reason}]",
        "/ban {user} [{reason}]",
        "/unban {user} [{reason}]",
        "/banlist",
        "/countbanlist",
        -- "/kickrandom",
        -- "/kickdeleted",
        "OWNER",
        -- "/kicknouser",
        -- "/kickinactive [{msgs}]",
        "ADMIN",
        "/banlist {group_id}",
        "/countbanlist {group_id}",
        "/gban {user}",
        "/ungban {user}",
        "/gbanlist",
        "/countgbanlist",
    },
}