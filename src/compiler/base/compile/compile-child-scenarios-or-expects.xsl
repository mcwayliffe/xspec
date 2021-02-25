<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:local="urn:x-xspec:compiler:base:compile:compile-child-scenarios-or-expects:local"
                xmlns:x="http://www.jenitennison.com/xslt/xspec"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                exclude-result-prefixes="#all"
                version="3.0">

   <!--
      Drive the compilation of (child::x:scenario | child::x:expect) to either XSLT named templates
      or XQuery functions, taking x:pending into account.
   -->
   <xsl:template name="x:compile-child-scenarios-or-expects" as="node()*">
      <!-- Context item is x:description or x:scenario -->
      <xsl:context-item as="element()" use="required" />

      <xsl:param name="pending" as="node()?"
         select="descendant-or-self::x:scenario[@focus][1]/@focus" tunnel="yes" />

      <xsl:variable name="this" select="." as="element()"/>
      <xsl:if test="empty($this[self::x:description|self::x:scenario])">
         <xsl:message terminate="yes"
            select="'$this must be a description or a scenario, but is: ' || name()" />
      </xsl:if>

      <xsl:apply-templates select="$this/element()" mode="local:compile-scenarios-or-expects">
         <xsl:with-param name="pending" select="$pending" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:template>

   <!--
      mode="local:compile-scenarios-or-expects"
      Must be "fired" by the named template "x:compile-child-scenarios-or-expects".
   -->
   <xsl:mode name="local:compile-scenarios-or-expects" on-multiple-match="fail"
      on-no-match="deep-skip" />

   <!--
      At x:pending elements, we switch the $pending tunnel param value for children.
   -->
   <xsl:template match="x:pending" as="node()+" mode="local:compile-scenarios-or-expects">
      <xsl:apply-templates select="element()" mode="#current">
         <xsl:with-param name="pending" select="x:label(.)" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:template>

   <!--
      Compile x:scenario.
   -->
   <xsl:template match="x:scenario" as="node()+" mode="local:compile-scenarios-or-expects">
      <xsl:param name="apply" as="element(x:apply)?" tunnel="yes" />
      <xsl:param name="call" as="element(x:call)?" tunnel="yes" />
      <xsl:param name="context" as="element(x:context)?" tunnel="yes" />
      <xsl:param name="pending" as="node()?" required="yes" tunnel="yes" />

      <!-- The new $pending. -->
      <xsl:variable name="pending" as="node()?" select="
          if ( @focus ) then
            ()
          else if ( @pending ) then
            @pending
          else
            $pending"/>
      <xsl:variable name="pending-p" as="xs:boolean" select="x:pending-p(., $pending)" />

      <!-- The new apply. -->
      <xsl:variable name="new-apply" as="element(x:apply)?">
         <xsl:choose>
            <xsl:when test="x:apply">
               <xsl:copy select="x:apply">
                  <xsl:sequence select="($apply, .) ! attribute()" />

                  <xsl:variable name="local-params" as="element(x:param)*" select="x:param"/>
                  <xsl:sequence
                     select="
                        $apply/x:param[not(@name = $local-params/@name)],
                        $local-params" />
               </xsl:copy>
               <!-- TODO: Test that "x:apply/(node() except x:param)" is empty. -->
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$apply"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <!-- The new context. -->
      <xsl:variable name="new-context" as="element(x:context)?">
         <xsl:choose>
            <xsl:when test="x:context">
               <xsl:copy select="x:context">
                  <xsl:sequence select="($context, .)  ! attribute()" />

                  <xsl:variable name="local-params" as="element(x:param)*" select="x:param"/>
                  <xsl:sequence
                     select="
                        $context/x:param[not(@name = $local-params/@name)],
                        $local-params"/>

                  <xsl:sequence
                     select="
                        if (node() except x:param) then
                           (node() except x:param)
                        else
                           $context/(node() except x:param)" />
               </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$context"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <!-- The new call. -->
      <xsl:variable name="new-call" as="element(x:call)?">
         <xsl:choose>
            <xsl:when test="x:call">
               <xsl:copy select="x:call">
                  <xsl:sequence select="($call, .) ! attribute()" />

                  <xsl:variable name="is-function-call" as="xs:boolean"
                     select="($call, .)/@function => exists()" />
                  <xsl:variable name="local-params" as="element(x:param)*">
                     <xsl:for-each select="x:param">
                        <xsl:copy>
                           <xsl:if test="$is-function-call">
                              <xsl:attribute name="position" select="position()" />
                           </xsl:if>
                           <xsl:sequence select="attribute() | node()" />
                        </xsl:copy>
                     </xsl:for-each>
                  </xsl:variable>

                  <xsl:sequence
                     select="
                        $call/x:param
                        [not(@name = $local-params/@name)]
                        [not(@position = $local-params/@position)],
                        $local-params"/>
               </xsl:copy>
               <!-- TODO: Test that "x:call/(node() except x:param)" is empty. -->
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$call"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <!-- Check duplicate parameter name/position-->
      <xsl:variable name="dup-param-error-string" as="xs:string?"
         select="
            (
               ($new-apply, $new-call, $new-context) ! local:param-dup-name-error-string(.),
               $new-call[@function] ! local:param-dup-position-error-string(.)
            )[1]" />
      <xsl:if test="$dup-param-error-string">
         <xsl:call-template name="x:diag-compiling-scenario">
            <xsl:with-param name="message" select="$dup-param-error-string" />
         </xsl:call-template>
      </xsl:if>

      <!-- Check x:apply -->
      <!-- TODO: Remove this after implementing x:apply -->
      <xsl:if test="$new-apply">
         <xsl:message>
            <xsl:text expand-text="yes">WARNING: The instruction {name($new-apply)} is not supported yet!</xsl:text>
         </xsl:message>
      </xsl:if>

      <!-- Dispatch to a language-specific (XSLT or XQuery) worker template -->
      <xsl:call-template name="x:compile-scenario">
         <xsl:with-param name="apply" select="$new-apply" tunnel="yes" />
         <xsl:with-param name="call" select="$new-call" tunnel="yes" />
         <xsl:with-param name="context" select="$new-context" tunnel="yes" />
         <xsl:with-param name="pending" select="$pending" tunnel="yes" />
         <xsl:with-param name="pending-p" select="$pending-p" />
         <xsl:with-param name="run-sut-now" select="not($pending-p) and x:expect" />
      </xsl:call-template>
   </xsl:template>

   <!--
      Compile x:expect.
   -->
   <xsl:template match="x:expect" as="node()+" mode="local:compile-scenarios-or-expects">
      <xsl:param name="call" as="element(x:call)?" required="yes" tunnel="yes" />
      <xsl:param name="context" as="element(x:context)?" required="yes" tunnel="yes" />
      <xsl:param name="pending" as="node()?" required="yes" tunnel="yes" />

      <xsl:variable name="pending" as="node()?"
         select="($pending, ancestor::x:scenario/@pending)[1]" />
      <xsl:variable name="pending-p" as="xs:boolean" select="x:pending-p(., $pending)" />

      <!-- Dispatch to a language-specific (XSLT or XQuery) worker template -->
      <xsl:call-template name="x:compile-expect">
         <xsl:with-param name="call" select="$call" tunnel="yes" />
         <xsl:with-param name="context" select="$context" tunnel="yes" />
         <xsl:with-param name="pending" select="$pending" tunnel="yes" />
         <xsl:with-param name="pending-p" select="$pending-p" />
         <xsl:with-param name="param-uqnames" as="xs:string*">
            <xsl:if test="not($pending-p)">
               <xsl:sequence select="$context ! x:known-UQName('x:context')" />
               <xsl:sequence select="x:known-UQName('x:result')" />
            </xsl:if>
            <xsl:sequence select="accumulator-before('stacked-vardecls-distinct-uqnames')" />
         </xsl:with-param>
      </xsl:call-template>
   </xsl:template>

   <!--
      Local functions
   -->

   <!-- Returns an error string if the given element has duplicate x:param/@name -->
   <xsl:function name="local:param-dup-name-error-string" as="xs:string?">
      <!-- x:apply, x:call or x:context -->
      <xsl:param name="owner" as="element()" />

      <xsl:variable name="uqnames" as="xs:string*"
         select="$owner/x:param ! x:variable-UQName(.)" />
      <xsl:for-each select="$uqnames[subsequence($uqnames, 1, position() - 1) = .][1]">
         <xsl:text expand-text="yes">Duplicate parameter name, {.}, used in {name($owner)}.</xsl:text>
      </xsl:for-each>
   </xsl:function>

   <!-- Returns an error string if the given element has duplicate x:param/@position -->
   <xsl:function name="local:param-dup-position-error-string" as="xs:string?">
      <xsl:param name="owner" as="element(x:call)" />

      <xsl:variable name="positions" as="xs:integer*"
         select="$owner/x:param ! xs:integer(@position)" />
      <xsl:for-each select="$positions[subsequence($positions, 1, position() - 1) = .][1]">
         <xsl:text expand-text="yes">Duplicate parameter position, {.}, used in {name($owner)}.</xsl:text>
      </xsl:for-each>
   </xsl:function>

</xsl:stylesheet>