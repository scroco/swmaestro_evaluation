# coding: utf-8
require 'capybara'
require 'capybara/dsl'

require 'nokogiri'
require 'open-uri'

Capybara.run_server = false
Capybara.current_driver = :selenium
Capybara.app_host = 'http://swmaestro.kr'

module SWMaestro
  class ResumeExtractor
    include Capybara::DSL

    attr_accessor :username, :password, :output_file

    def execute
      delete_file

      login # 로그인 한 후 목록 페이지로 자동으로 리다이렉트 됨

      doc = Nokogiri::HTML(page.body)

      wrap_html do
        # 페이지네이션 처리
        doc.css("li.pagingNumbering").each_with_index do |link, idx|
          # click_link를 하고 싶었으나 element 식별자를 찾기 어렵고, 링크도 아닌 일반 li를 클릭하면 POST로 처리하고 있음.
          # 그래서 DOM을 찾은 후 클릭
          page.find('li.pagingNumbering', :text => link.content).click

          puts "[#{idx + 1} 페이지 처리 시작]"

          page_doc = Nokogiri::HTML(page.body)

          # .txt01이 지원자들의 고유번호를 갖고 있는 링크의 클래스
          page_doc.css(".txt01").each do |link|
            # 고유번호만으로는 나중에 참조하기 어려우므로 일련번호도 찾아서 넣도록 함
            seq_no = link.ancestors("tr").css("td:first").first.content

            click_link link.content # 테이블에서 고유번호 링크 클릭후 상세 페이지로 이동
            click_link "정보보기" # 정보보기 클릭. 고유 URL이 있으면 편하겠지만 없다. 모두 POST로 처리하면서 상태를 이용하고 있음.

            # 팝업 윈도우 처리
            new_window=page.driver.browser.window_handles.last
            page.within_window new_window do
              head_str = "[#{seq_no}] #{link.content}"
              resume_doc = Nokogiri::HTML(page.body)
              write_to_file "<div class='resume'>"
              write_to_file "<h1 class='resume-id'>#{head_str}</h1>"
              write_to_file resume_doc.css("#sub_cont")[0].to_s.gsub("../../../", "http://swmaestro.kr/")
              write_to_file "</div>"

              puts " * #{head_str} 처리"
            end
          end
        end
      end
    end

    private
    def login
      visit('/jsp/hj/hj01/evaluation.do')
      within("form[name=frm_login]") do
        fill_in 'LOGIN_ID', :with => username
        fill_in 'LOGIN_PW', :with => password
        click_link ''
      end
    end

    def wrap_html
      write_to_file "<html>"
      write_to_file File.read("html_head.txt")
      write_to_file "<body>"

      yield

      write_to_file "</body></html>"
    end

    def delete_file
      File.delete(output_file) if File.exist? output_file
    end

    def write_to_file content
      File.open(output_file, 'a') {|f| f.write(content) }
    end
  end
end

extractor = SWMaestro::ResumeExtractor.new

extractor.output_file = "resumes.html"

# TODO 수정해 주세요.
extractor.username = "아이디"
extractor.password = "패스워드"

extractor.execute