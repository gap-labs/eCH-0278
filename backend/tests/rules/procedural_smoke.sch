<sch:schema xmlns:sch="http://purl.oclc.org/dsdl/schematron" queryBinding="xslt3">
  <sch:title>Procedural smoke rules (test-only)</sch:title>
  <sch:ns prefix="eCH-0278" uri="http://www.ech.ch/xmlns/eCH-0278/1" />

  <sch:pattern id="procedural-smoke-pattern">
    <sch:rule context="//*[@taxProcedure]">
      <sch:report id="time_taxation_marker_present" role="info" test="@taxProcedure='taxation'">
        Taxation marker present in document.
      </sch:report>
    </sch:rule>
  </sch:pattern>
</sch:schema>